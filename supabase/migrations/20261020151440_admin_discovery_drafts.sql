-- Dynamic admin catalogue and drafts. Prepared migration, not deployed as fixed72.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
DO $$ BEGIN
 IF to_regnamespace('private_admin') IS NULL OR to_regnamespace('private_discovery_admin') IS NOT NULL
 OR NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.profiles'::regclass
   AND conname='profiles_role_check' AND pg_get_constraintdef(oid)=
   'CHECK ((role = ANY (ARRAY[''customer''::text, ''admin''::text])))')
 OR has_column_privilege('authenticated','public.profiles','role','UPDATE')
 THEN RAISE EXCEPTION 'discovery_admin_requires_R1_without_drift'; END IF;
END $$;
CREATE SCHEMA private_discovery_admin;
REVOKE ALL ON SCHEMA private_discovery_admin FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE private_discovery_admin.draft (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 revision bigint NOT NULL CHECK(revision BETWEEN 1 AND 2147483647),
 payload jsonb NOT NULL, updated_by uuid, updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE private_discovery_admin.versions (
 revision bigint PRIMARY KEY, base_revision bigint, request_id uuid UNIQUE, actor_id uuid,
 reason text NOT NULL CHECK(char_length(reason) BETWEEN 1 AND 500),
 changed_at timestamptz NOT NULL DEFAULT now(), payload jsonb NOT NULL, payload_hash text NOT NULL
);
CREATE TABLE private_discovery_admin.destinations (
 id text PRIMARY KEY CHECK(id ~ '^[a-z0-9][a-z0-9/-]{0,119}$'),
 name text NOT NULL CHECK(name=btrim(name) AND char_length(name) BETWEEN 1 AND 180 AND name !~ '[[:cntrl:]]'),
 slug text NOT NULL UNIQUE CHECK(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug)<=120),
 description text NOT NULL CHECK(char_length(description)<=10000),
 image_url text CHECK(image_url IS NULL OR image_url ~ '^https://[^/@[:space:]]+(/[^[:space:]]*)?$'),
 region text NOT NULL CHECK(char_length(region)<=80), is_active boolean NOT NULL
);
CREATE TABLE private_discovery_admin.places (
 id text PRIMARY KEY CHECK(id ~ '^[a-z0-9][a-z0-9/-]{0,119}$'),
 destination_id text NOT NULL REFERENCES private_discovery_admin.destinations(id) ON DELETE RESTRICT ON UPDATE RESTRICT,
 name text NOT NULL CHECK(name=btrim(name) AND char_length(name) BETWEEN 1 AND 180 AND name !~ '[[:cntrl:]]'),
 slug text NOT NULL CHECK(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND char_length(slug)<=120),
 description text NOT NULL CHECK(char_length(description)<=10000),
 image_url text CHECK(image_url IS NULL OR image_url ~ '^https://[^/@[:space:]]+(/[^[:space:]]*)?$'),
 latitude double precision CHECK(latitude BETWEEN -90 AND 90),
 longitude double precision CHECK(longitude BETWEEN -180 AND 180),
 is_active boolean NOT NULL,
 CHECK((latitude IS NULL)=(longitude IS NULL)), UNIQUE(destination_id,slug)
);
ALTER TABLE private_discovery_admin.destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_discovery_admin.places ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_discovery_admin.draft ENABLE ROW LEVEL SECURITY;
ALTER TABLE private_discovery_admin.versions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA private_discovery_admin FROM PUBLIC,anon,authenticated,service_role;
-- Import the existing facts unchanged, including checkedAt and unresolved gaps.
INSERT INTO private_discovery_admin.draft(singleton,revision,payload)
 VALUES(true,1,$visit_seed${
  "schemaVersion": 1,
  "version": 1,
  "publishedAt": "2026-10-20T00:00:00Z",
  "catalogueSha256": "c14cecc97149a3acf64f439d44662333bbb8756bd580e18f368ac053bdd1542a",
  "timezone": "Asia/Ho_Chi_Minh",
  "sources": [
    {
      "id": "vm-visitor",
      "title": "Thông tin cho du khách",
      "publisher": "Trung tâm Văn Miếu – Quốc Tử Giám",
      "url": "https://www.vanmieu.gov.vn/vi/introduction/visitor-information"
    },
    {
      "id": "vnat-hanoi",
      "title": "11 điểm du lịch không thể bỏ qua tại Hà Nội — mục Hồ Hoàn Kiếm",
      "publisher": "Cục Du lịch Quốc gia Việt Nam",
      "url": "https://image.vietnam.travel/vi/things-to-do/11-must-see-attractions-ha-noi"
    },
    {
      "publisher": "Ban quản lý di sản thế giới vịnh Hạ Long – Yên Tử",
      "url": "https://halongbay.com.vn/p/58-muc-phi-tham-quan-vinh-ha-long",
      "publishedAt": "2025-03-31",
      "id": "halong-fees",
      "title": "Mức phí tham quan vịnh Hạ Long"
    },
    {
      "publisher": "Ban quản lý di sản thế giới vịnh Hạ Long – Yên Tử",
      "url": "https://halongbay.com.vn/p/71-thoi-gian-don-tra-khach-ve-cang-ben",
      "publishedAt": "2024-11-06",
      "id": "halong-hours",
      "title": "Thời gian đón khách tham quan"
    },
    {
      "publisher": "Ban quản lý vịnh Hạ Long",
      "url": "https://halongbay.com.vn/en/places/5-hon-trong-mai",
      "id": "halong-trong-mai",
      "title": "Trong Mai Islet (Ga Choi Islet)"
    },
    {
      "publisher": "Tuần Châu Verse — Tập đoàn Tuần Châu",
      "url": "https://booking.tuanchauverse.com/vi/combo-tuan-chau-park",
      "id": "tuan-park4",
      "title": "Combo vé 4 công viên Tuần Châu Park"
    },
    {
      "publisher": "Tuần Châu Verse — Tập đoàn Tuần Châu",
      "url": "https://booking.tuanchauverse.com/vi/tuan-chau-farm",
      "id": "tuan-park3",
      "title": "Combo 3 công viên kèm đồ uống cho người lớn"
    },
    {
      "publisher": "Tuần Châu Verse — Tập đoàn Tuần Châu",
      "url": "https://booking.tuanchauverse.com/vi/hours",
      "id": "tuan-hours",
      "effectiveFrom": "2026-05-04",
      "title": "Giờ hoạt động Tuần Châu Park"
    },
    {
      "publisher": "Tuần Châu Verse — Tập đoàn Tuần Châu",
      "url": "https://booking.tuanchauverse.com/vi/news/tuan-chau-park-cam-nang-kham-pha-cong-vien-giai-tri-da-dang-tai-dao-tuan-chau-tu-a-den-z",
      "publishedAt": "2026-08-04",
      "id": "tuan-guide",
      "title": "Cẩm nang Tuần Châu Park — lịch các phân khu"
    },
    {
      "title": "Bảng phí: vé lẻ từ 02/06/2026, vé tuyến từ 04/01/2026",
      "id": "hue-fees-2026",
      "url": "https://hueworldheritage.org.vn/Thong-tin-tham-quan/Gia-ve",
      "publisher": "Trung tâm Bảo tồn Di tích Cố đô Huế"
    },
    {
      "title": "Thời gian bán vé và thời gian đóng cửa tham quan",
      "id": "hue-time",
      "url": "https://eticket.hueworldheritage.org.vn/thoi-gian-tham-quan",
      "publisher": "Trung tâm Bảo tồn Di tích Cố đô Huế"
    },
    {
      "title": "Nội quy tham quan",
      "id": "hue-rules",
      "url": "https://eticket.hueworldheritage.org.vn/noi-quy",
      "publisher": "Trung tâm Bảo tồn Di tích Cố đô Huế"
    },
    {
      "title": "Hồ sơ Chợ Đông Ba trên Huetripo",
      "id": "hue-dongba-directory",
      "url": "https://huetripo.hue.gov.vn/co-so-dich-vu/cho-/cho-dong-ba-hue-759007",
      "publisher": "Cổng Huetripo — Thành phố Huế"
    },
    {
      "publisher": "Trung tâm Bảo tồn Di sản văn hóa thế giới Hội An",
      "publishedAt": "2026-03-16",
      "url": "https://hoianworldheritage.org.vn/vi/news/Du-lich-Hoi-An/cap-nhat-ve-tham-quan-khu-pho-co-hoi-an-hanh-trinh-cham-ve-nguyen-ban-giua-long-di-san-3033.hwh",
      "title": "Vé tham quan phố cổ — quyền lợi hai gói",
      "id": "hoian-fees-2026"
    },
    {
      "publisher": "Trung tâm Bảo tồn Di sản văn hóa thế giới Hội An",
      "publishedAt": "2020-02-23",
      "url": "https://www.hoianworldheritage.org.vn/vi/news/Dieu-can-biet/ve-tham-quan-hoi-an-1940.hwh",
      "title": "Danh mục di tích trong vé Hội An — dùng đối chiếu tên điểm",
      "id": "hoian-ticket-sites"
    },
    {
      "publisher": "Cổng Hội An Thành phố sáng tạo — mục tổng hợp",
      "url": "https://hoiancreativecity.com/vi/bao-tang-lich-su-van-hoa-hoi-an-minh-chung-song-dong-cua-thuong-cang-phon-thinh-mot-thoi",
      "title": "Bảo tàng Lịch sử – Văn hóa Hội An — hồ sơ giới thiệu",
      "id": "hoian-museum-hours"
    },
    {
      "publisher": "Cổng Hội An Thành phố sáng tạo — bài dẫn Traveloka",
      "url": "https://hoiancreativecity.com/vi/nha-co-tan-ky-noi-luu-giu-ve-dep-xua-cu-cua-hoi-an",
      "title": "Nhà cổ Tấn Ký — giờ sáng/chiều trong hồ sơ giới thiệu",
      "id": "hoian-tanky-hours"
    },
    {
      "publisher": "Ban quản lý Di tích Danh thắng Ngũ Hành Sơn",
      "title": "Giá vé và thời gian phục vụ Ngũ Hành Sơn",
      "id": "marble-management",
      "publishedAt": "2014-06-18",
      "url": "https://nguhanhson.org/news/thong-tin-can-biet/gia-ve-tham-quan/"
    },
    {
      "publisher": "Trung tâm Xúc tiến Du lịch TP. Đà Nẵng",
      "title": "Bảng giá tham khảo năm 2026 — mục Ngũ Hành Sơn",
      "id": "danang-fees-2026",
      "publishedAt": "2026-01-22",
      "url": "https://danangfantasticity.com/ja/tin-tuc/len-lich-kham-pha-da-nang-2026-cap-nhat-gia-ve-tham-quan-cac-diem-khu-du-lich"
    },
    {
      "publisher": "Trung tâm Xúc tiến Du lịch Đà Nẵng",
      "title": "Bảng giá tham quan 2023 — mục Sơn Trà và Linh Ứng",
      "publishedAt": "2023-01-03",
      "id": "danang-fees-2023",
      "url": "https://danangfantasticity.com/en/gia-ve-cac-diem-tham-quan-tai-da-nang-2023",
      "effectiveFrom": "2023-01-01"
    },
    {
      "publisher": "Trung tâm Xúc tiến Du lịch Đà Nẵng",
      "title": "Bán đảo Sơn Trà — ba tuyến và khung giờ theo mùa",
      "id": "sontra-route-rules",
      "url": "https://danangfantasticity.com/en/di-san-canh-quan/ban-dao-son-tra"
    },
    {
      "publisher": "Trung tâm Xúc tiến Du lịch Đà Nẵng",
      "title": "Đèo Hải Vân — chi phí ngắm cảnh và lưu ý hành trình",
      "id": "haivan-landscape",
      "publishedAt": "2025-08-01",
      "url": "https://danangfantasticity.com/ja/di-san-canh-quan/deo-hai-van-thien-ha-de-nhat-hung-quan"
    },
    {
      "publisher": "Trung tâm Xúc tiến Du lịch TP. Đà Nẵng",
      "title": "Chợ Hàn — khung giờ tham khảo trong hướng dẫn chợ địa phương",
      "id": "han-market-reference",
      "publishedAt": "2026-06-12",
      "url": "https://danangfantasticity.com/cn/am-thuc-dia-phuong/kham-pha-am-thuc-da-nang-tai-6-khu-cho-dia-phuong-noi-tieng"
    },
    {
      "publisher": "Chùa Linh Ứng Bãi Bụt",
      "title": "Những lời nhắc nhở khách tham quan chùa Linh Ứng Bãi Bụt",
      "id": "linhung-visitor-rules",
      "url": "https://chualinhung.vn/"
    }
  ],
  "packages": [
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Thiên Cung",
        "Đầu Gỗ",
        "Trống Mái"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL1 ban ngày",
      "id": "halong-vhl1-day",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Sửng Sốt",
        "Mê Cung",
        "Các điểm thuộc hành trình VHL2"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL2 ban ngày",
      "id": "halong-vhl2-day",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Cửa Vạn",
        "Tiên Ông",
        "Các điểm thuộc hành trình VHL3"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL3 ban ngày",
      "id": "halong-vhl3-day",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Các điểm thuộc hành trình VHL4"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL4 ban ngày",
      "id": "halong-vhl4-day",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Thiên Cung",
        "Trống Mái",
        "Gia Luận"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL5 tới Gia Luận",
      "id": "halong-vhl5-day",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Các điểm thuộc hành trình VHL6"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL6 ban ngày",
      "id": "halong-vhl6-day",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Các hành trình VHL1–4 theo sản phẩm khám phá"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL7 — chỉ du thuyền khám phá",
      "id": "halong-vhl7-day",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Hành trình ven bờ theo nguồn"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL8 ven bờ",
      "id": "halong-vhl8-day",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Tuyến 2 và lưu trú 1 đêm theo biểu phí"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL2 lưu trú 1 đêm, tối đa 24 giờ",
      "id": "halong-vhl2-night1",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Tuyến 2 và lưu trú 2 đêm theo biểu phí"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL2 lưu trú 2 đêm, tối đa 48 giờ",
      "id": "halong-vhl2-night2",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Tuyến 3 và lưu trú 1 đêm theo biểu phí"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL3 lưu trú 1 đêm, tối đa 24 giờ",
      "id": "halong-vhl3-night1",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Tuyến 3 và lưu trú 2 đêm theo biểu phí"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL3 lưu trú 2 đêm, tối đa 48 giờ",
      "id": "halong-vhl3-night2",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Tuyến 4 và lưu trú 1 đêm theo biểu phí"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL4 lưu trú 1 đêm, tối đa 24 giờ",
      "id": "halong-vhl4-night1",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "halong-fees"
      ],
      "included": [
        "Tuyến 4 và lưu trú 2 đêm theo biểu phí"
      ],
      "excluded": [],
      "scope": "Phí chung của hành trình, không phải phí riêng từng hang/điểm.",
      "label": "VHL4 lưu trú 2 đêm, tối đa 48 giờ",
      "id": "halong-vhl4-night2",
      "conditions": [
        "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
        "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
      ]
    },
    {
      "sourceIds": [
        "tuan-park4",
        "tuan-hours"
      ],
      "included": [
        "Show cá heo, hải cẩu",
        "Tuần Châu Farm",
        "Tuần Châu Farm Hill",
        "King Kong Park"
      ],
      "excluded": [],
      "scope": "Tuần Châu Park, không phải vé toàn đảo/cảng/phà",
      "label": "Combo 4 công viên",
      "id": "tuan-park4",
      "conditions": [
        "Vé cho một người, đúng ngày đã chọn."
      ]
    },
    {
      "sourceIds": [
        "tuan-park3"
      ],
      "included": [
        "Tuần Châu Farm",
        "Tuần Châu Farm Hill",
        "King Kong Park"
      ],
      "excluded": [
        "Show cá heo, hải cẩu"
      ],
      "scope": "Gói hiện ghi trên trang đặt vé, khác gói 3 công viên trong bài tổng quan cũ",
      "label": "Combo 3 công viên kèm đồ uống cho người lớn",
      "id": "tuan-park3-drink",
      "conditions": [
        "Đồ uống tặng được nêu cho vé người lớn; không tự áp cho vé trẻ em."
      ]
    },
    {
      "included": [
        "Lăng Minh Mạng",
        "Lăng Gia Long"
      ],
      "sourceIds": [
        "hue-fees-2026"
      ],
      "id": "hue-mm-gl",
      "scope": "Phí chung cả tuyến, không cộng lại cho mỗi di tích trong cùng gói.",
      "conditions": [
        "Theo bảng phí tuyến áp dụng từ 04/01/2026. Kiểm tra thời hạn sử dụng và điều kiện vé khi đặt."
      ],
      "label": "Minh Mạng + Gia Long",
      "excluded": []
    },
    {
      "included": [
        "Lăng Tự Đức",
        "Lăng Đồng Khánh"
      ],
      "sourceIds": [
        "hue-fees-2026"
      ],
      "id": "hue-td-dk",
      "scope": "Phí chung cả tuyến, không cộng lại cho mỗi di tích trong cùng gói.",
      "conditions": [
        "Theo bảng phí tuyến áp dụng từ 04/01/2026. Kiểm tra thời hạn sử dụng và điều kiện vé khi đặt."
      ],
      "label": "Tự Đức + Đồng Khánh",
      "excluded": []
    },
    {
      "included": [
        "Đại Nội",
        "Lăng Minh Mạng",
        "Lăng Khải Định"
      ],
      "sourceIds": [
        "hue-fees-2026"
      ],
      "id": "hue-dn-mm-kd",
      "scope": "Phí chung cả tuyến, không cộng lại cho mỗi di tích trong cùng gói.",
      "conditions": [
        "Theo bảng phí tuyến áp dụng từ 04/01/2026. Kiểm tra thời hạn sử dụng và điều kiện vé khi đặt."
      ],
      "label": "Đại Nội + Minh Mạng + Khải Định",
      "excluded": []
    },
    {
      "included": [
        "Đại Nội",
        "Lăng Minh Mạng",
        "Lăng Tự Đức"
      ],
      "sourceIds": [
        "hue-fees-2026"
      ],
      "id": "hue-dn-mm-td",
      "scope": "Phí chung cả tuyến, không cộng lại cho mỗi di tích trong cùng gói.",
      "conditions": [
        "Theo bảng phí tuyến áp dụng từ 04/01/2026. Kiểm tra thời hạn sử dụng và điều kiện vé khi đặt."
      ],
      "label": "Đại Nội + Minh Mạng + Tự Đức",
      "excluded": []
    },
    {
      "included": [
        "Đại Nội",
        "Lăng Tự Đức",
        "Lăng Khải Định"
      ],
      "sourceIds": [
        "hue-fees-2026"
      ],
      "id": "hue-dn-td-kd",
      "scope": "Phí chung cả tuyến, không cộng lại cho mỗi di tích trong cùng gói.",
      "conditions": [
        "Theo bảng phí tuyến áp dụng từ 04/01/2026. Kiểm tra thời hạn sử dụng và điều kiện vé khi đặt."
      ],
      "label": "Đại Nội + Tự Đức + Khải Định",
      "excluded": []
    },
    {
      "included": [
        "Đại Nội",
        "Lăng Minh Mạng",
        "Lăng Tự Đức",
        "Lăng Khải Định"
      ],
      "sourceIds": [
        "hue-fees-2026"
      ],
      "id": "hue-four",
      "scope": "Phí chung cả tuyến, không cộng lại cho mỗi di tích trong cùng gói.",
      "conditions": [
        "Theo bảng phí tuyến áp dụng từ 04/01/2026. Kiểm tra thời hạn sử dụng và điều kiện vé khi đặt."
      ],
      "label": "Đại Nội + Minh Mạng + Tự Đức + Khải Định",
      "excluded": []
    },
    {
      "included": [
        "Các điểm di tích thuộc tuyến gộp do Trung tâm công bố"
      ],
      "sourceIds": [
        "hue-fees-2026"
      ],
      "id": "hue-all",
      "scope": "Phí chung cả tuyến, không cộng lại cho mỗi di tích trong cùng gói.",
      "conditions": [
        "Theo bảng phí tuyến áp dụng từ 04/01/2026. Kiểm tra thời hạn sử dụng và điều kiện vé khi đặt."
      ],
      "label": "Tuyến gộp tất cả điểm di tích theo bảng phí",
      "excluded": []
    },
    {
      "included": [
        "Cảnh quan phố cổ",
        "Chọn Chùa Cầu hoặc Miếu Quan Công",
        "Hai công trình văn hóa tự chọn"
      ],
      "label": "Vé phố cổ 80.000đ",
      "id": "hoian-heritage-80",
      "sourceIds": [
        "hoian-fees-2026"
      ],
      "scope": "Vé chung nhiều điểm theo ô lựa chọn",
      "excluded": [
        "Dịch vụ mua riêng ngoài quyền lợi vé"
      ],
      "conditions": [
        "Dùng một lần mua trong thời gian lưu trú, tối đa 03 ngày; giữ cuống vé. Chọn điểm theo ô vé và xác nhận quyền lợi tại quầy.",
        "Các mức dưới đây là giá gói; không cộng lại khi ghé nhiều điểm bằng cùng vé. Không tự suy mức giảm theo tuổi, quốc tịch hoặc giấy tờ."
      ]
    },
    {
      "included": [
        "Cảnh quan phố cổ",
        "Chọn Chùa Cầu hoặc Miếu Quan Công",
        "Tự chọn hệ thống bảo tàng",
        "Ba công trình văn hóa tự chọn"
      ],
      "label": "Vé phố cổ 120.000đ",
      "id": "hoian-heritage-120",
      "sourceIds": [
        "hoian-fees-2026"
      ],
      "scope": "Vé chung nhiều điểm theo ô lựa chọn",
      "excluded": [
        "Dịch vụ mua riêng ngoài quyền lợi vé"
      ],
      "conditions": [
        "Dùng một lần mua trong thời gian lưu trú, tối đa 03 ngày; giữ cuống vé. Chọn điểm theo ô vé và xác nhận quyền lợi tại quầy.",
        "Các mức dưới đây là giá gói; không cộng lại khi ghé nhiều điểm bằng cùng vé. Không tự suy mức giảm theo tuổi, quốc tịch hoặc giấy tờ."
      ]
    }
  ],
  "places": [
    {
      "placeId": "ha-noi/hoan-kiem",
      "visitScopeLabel": "Đi dạo không gian công cộng quanh hồ; không gồm đền Ngọc Sơn hoặc dịch vụ",
      "price": {
        "status": "free",
        "options": [
          {
            "id": "public-walk",
            "label": "Đi dạo quanh hồ",
            "audience": "Khách đi dạo",
            "amountVnd": 0,
            "currency": "VND",
            "unit": "người",
            "included": [
              "Không gian công cộng ven hồ"
            ],
            "excluded": [
              "Đền Ngọc Sơn",
              "Dịch vụ và sự kiện có vé"
            ],
            "conditions": [
              "Tuân thủ điều tiết tại chỗ."
            ]
          }
        ],
        "evidence": {
          "sourceIds": [
            "vnat-hanoi"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Theo mục Hồ Hoàn Kiếm của cổng du lịch quốc gia; không áp dụng cho các điểm bán vé quanh hồ."
          ],
          "unresolvedIssues": []
        }
      },
      "hours": {
        "status": "no_fixed_hours",
        "rules": [],
        "notes": [
          "Nguồn mô tả khu vực hồ mở cả ngày. Không có khung giờ vào di tích trong hồ trong hồ sơ này; theo điều tiết, sự kiện và hạn chế tại chỗ."
        ],
        "evidence": {
          "sourceIds": [
            "vnat-hanoi"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Chỉ không gian công cộng ven hồ; không dùng làm lịch đền Ngọc Sơn hay lịch phố đi bộ."
          ],
          "unresolvedIssues": []
        }
      },
      "notes": []
    },
    {
      "placeId": "ha-noi/van-mieu",
      "visitScopeLabel": "Tham quan Văn Miếu – Quốc Tử Giám ban ngày; tour đêm là dịch vụ riêng",
      "price": {
        "status": "priced",
        "options": [
          {
            "id": "standard",
            "label": "Vé phổ thông ban ngày",
            "audience": "Người lớn phổ thông",
            "amountVnd": 70000,
            "currency": "VND",
            "unit": "người/lượt",
            "included": [
              "Tham quan ban ngày"
            ],
            "excluded": [
              "Tour đêm"
            ],
            "conditions": []
          },
          {
            "id": "student",
            "label": "Vé ưu tiên",
            "audience": "Học sinh, sinh viên các trường tại Việt Nam",
            "amountVnd": 35000,
            "currency": "VND",
            "unit": "người/lượt",
            "included": [],
            "excluded": [
              "Tour đêm"
            ],
            "conditions": [
              "Mang thẻ học sinh, sinh viên."
            ]
          },
          {
            "id": "priority",
            "label": "Vé ưu tiên",
            "audience": "Người từ 60 tuổi; người khuyết tật nặng; đối tượng ưu đãi văn hóa",
            "amountVnd": 35000,
            "currency": "VND",
            "unit": "người/lượt",
            "included": [],
            "excluded": [
              "Tour đêm"
            ],
            "conditions": [
              "Mang CCCD hoặc giấy tờ chứng minh theo quy định."
            ]
          },
          {
            "id": "eligible-free",
            "label": "Miễn phí theo đối tượng",
            "audience": "Trẻ dưới 16 tuổi; người khuyết tật đặc biệt nặng",
            "amountVnd": 0,
            "currency": "VND",
            "unit": "người/lượt",
            "included": [],
            "excluded": [
              "Tour đêm"
            ],
            "conditions": [
              "Chỉ áp dụng đúng đối tượng theo nguồn."
            ]
          }
        ],
        "evidence": {
          "sourceIds": [
            "vm-visitor"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Đối chiếu nguồn đơn vị quản lý; không áp giá vé ban ngày cho tour đêm."
          ],
          "unresolvedIssues": []
        }
      },
      "hours": {
        "status": "scheduled",
        "rules": [
          {
            "label": "Tham quan ban ngày, hằng ngày",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 480,
            "endMinutes": 1020,
            "endDayOffset": 0
          }
        ],
        "notes": [
          "Nguồn còn công bố tour đêm 18:30–22:00 thứ Tư, thứ Bảy, Chủ nhật; kiểm tra vé riêng trước khi đặt."
        ],
        "evidence": {
          "sourceIds": [
            "vm-visitor"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Lịch công bố, không phải trạng thái mở cửa trực tiếp tại thời điểm xem."
          ],
          "unresolvedIssues": []
        }
      },
      "notes": []
    },
    {
      "placeId": "ha-noi/old-quarter",
      "visitScopeLabel": "Phố cổ Hà Nội",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": [
        "Giá và giờ của từng di tích, cửa hàng khác với không gian đường phố."
      ]
    },
    {
      "placeId": "ha-noi/opera",
      "visitScopeLabel": "Nhà hát Lớn Hà Nội",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": [
        "Giá và lịch phụ thuộc chương trình hoặc tour được chọn; kiểm tra chương trình cụ thể trước khi đặt."
      ]
    },
    {
      "placeId": "ha-noi/one-pillar",
      "visitScopeLabel": "Chùa Một Cột",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": [
        "Cần xác nhận phí theo đối tượng và lịch tiếp đón trước khi đi."
      ]
    },
    {
      "placeId": "ha-noi/st-joseph",
      "visitScopeLabel": "Nhà thờ Lớn Hà Nội",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": [
        "Giờ lễ khác giờ khách tham quan. Xác nhận lịch tham quan và tôn trọng sinh hoạt tôn giáo."
      ]
    },
    {
      "placeId": "ha-long/bay",
      "visitScopeLabel": "Tham quan vịnh bằng tàu theo tuyến; giờ dưới đây là khung xuất/về bến, không phải giờ mở từng hang",
      "price": {
        "evidence": {
          "sourceIds": [
            "halong-fees"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
            "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
          ],
          "unresolvedIssues": []
        },
        "options": [
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL1",
            "amountVnd": 250000,
            "id": "halong-vhl1-day",
            "packageId": "halong-vhl1-day",
            "label": "VHL1 ban ngày",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL2",
            "amountVnd": 250000,
            "id": "halong-vhl2-day",
            "packageId": "halong-vhl2-day",
            "label": "VHL2 ban ngày",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL3",
            "amountVnd": 200000,
            "id": "halong-vhl3-day",
            "packageId": "halong-vhl3-day",
            "label": "VHL3 ban ngày",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL4",
            "amountVnd": 200000,
            "id": "halong-vhl4-day",
            "packageId": "halong-vhl4-day",
            "label": "VHL4 ban ngày",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL5",
            "amountVnd": 250000,
            "id": "halong-vhl5-day",
            "packageId": "halong-vhl5-day",
            "label": "VHL5 tới Gia Luận",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL6",
            "amountVnd": 150000,
            "id": "halong-vhl6-day",
            "packageId": "halong-vhl6-day",
            "label": "VHL6 ban ngày",
            "unit": "người/ngày",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL7",
            "amountVnd": 600000,
            "id": "halong-vhl7-day",
            "packageId": "halong-vhl7-day",
            "label": "VHL7 — chỉ du thuyền khám phá",
            "unit": "người/lần",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL8",
            "amountVnd": 70000,
            "id": "halong-vhl8-day",
            "packageId": "halong-vhl8-day",
            "label": "VHL8 ven bờ",
            "unit": "người/lần",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL2",
            "amountVnd": 550000,
            "id": "halong-vhl2-night1",
            "packageId": "halong-vhl2-night1",
            "label": "VHL2 lưu trú 1 đêm, tối đa 24 giờ",
            "unit": "người/lần",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL2",
            "amountVnd": 750000,
            "id": "halong-vhl2-night2",
            "packageId": "halong-vhl2-night2",
            "label": "VHL2 lưu trú 2 đêm, tối đa 48 giờ",
            "unit": "người/lần",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL3",
            "amountVnd": 500000,
            "id": "halong-vhl3-night1",
            "packageId": "halong-vhl3-night1",
            "label": "VHL3 lưu trú 1 đêm, tối đa 24 giờ",
            "unit": "người/lần",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL3",
            "amountVnd": 650000,
            "id": "halong-vhl3-night2",
            "packageId": "halong-vhl3-night2",
            "label": "VHL3 lưu trú 2 đêm, tối đa 48 giờ",
            "unit": "người/lần",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL4",
            "amountVnd": 500000,
            "id": "halong-vhl4-night1",
            "packageId": "halong-vhl4-night1",
            "label": "VHL4 lưu trú 1 đêm, tối đa 24 giờ",
            "unit": "người/lần",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL4",
            "amountVnd": 650000,
            "id": "halong-vhl4-night2",
            "packageId": "halong-vhl4-night2",
            "label": "VHL4 lưu trú 2 đêm, tối đa 48 giờ",
            "unit": "người/lần",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          }
        ],
        "status": "bundled"
      },
      "hours": {
        "rules": [
          {
            "label": "Khung xuất/về bến mùa hè",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 300,
            "endMinutes": 1200,
            "endDayOffset": 0,
            "seasonStart": "04-01",
            "seasonEnd": "10-31",
            "lastReturnMinutes": 1200
          },
          {
            "label": "Khung xuất/về bến mùa đông",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 330,
            "endMinutes": 1140,
            "endDayOffset": 0,
            "seasonStart": "11-01",
            "seasonEnd": "03-31",
            "lastReturnMinutes": 1140
          }
        ],
        "evidence": {
          "sourceIds": [
            "halong-hours"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Mùa của cảng bắt đầu 01/4, khác mùa đón khách từng hang bắt đầu 16/4."
          ],
          "unresolvedIssues": []
        },
        "notes": [
          "Nguồn nêu giờ bắt đầu xuất bến và hạn về bến; giờ về bến không phải giờ còn được lên chuyến mới. Kiểm tra giờ chuyến đã đặt."
        ],
        "status": "seasonal"
      },
      "notes": []
    },
    {
      "placeId": "ha-long/sung-sot",
      "visitScopeLabel": "Tham quan điểm trong hành trình vịnh; phí tuyến dùng chung, không phải vé lẻ hang",
      "price": {
        "evidence": {
          "sourceIds": [
            "halong-fees"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
            "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
          ],
          "unresolvedIssues": []
        },
        "options": [
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL2",
            "amountVnd": 250000,
            "id": "halong-vhl2-day",
            "packageId": "halong-vhl2-day",
            "label": "VHL2 ban ngày",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          }
        ],
        "status": "bundled"
      },
      "hours": {
        "rules": [
          {
            "label": "Đón khách mùa hè",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 450,
            "endMinutes": 1050,
            "endDayOffset": 0,
            "seasonStart": "04-16",
            "seasonEnd": "10-31"
          },
          {
            "label": "Đón khách mùa đông",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 450,
            "endMinutes": 1020,
            "endDayOffset": 0,
            "seasonStart": "11-01",
            "seasonEnd": "04-15"
          }
        ],
        "evidence": {
          "sourceIds": [
            "halong-hours"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Theo lịch quản lý công bố 06/11/2024; kiểm tra thông báo trước khi khởi hành."
          ],
          "unresolvedIssues": []
        },
        "notes": [
          "Lịch đón khách tại điểm, không phải giờ tàu xuất/về cảng. Tuân thủ điều tiết và thời tiết ngày đi."
        ],
        "status": "seasonal"
      },
      "notes": []
    },
    {
      "placeId": "ha-long/me-cung",
      "visitScopeLabel": "Tham quan điểm trong hành trình vịnh; phí tuyến dùng chung, không phải vé lẻ hang",
      "price": {
        "evidence": {
          "sourceIds": [
            "halong-fees"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
            "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
          ],
          "unresolvedIssues": []
        },
        "options": [
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL2",
            "amountVnd": 250000,
            "id": "halong-vhl2-day",
            "packageId": "halong-vhl2-day",
            "label": "VHL2 ban ngày",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          }
        ],
        "status": "bundled"
      },
      "hours": {
        "rules": [
          {
            "label": "Đón khách mùa hè",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 480,
            "endMinutes": 1050,
            "endDayOffset": 0,
            "seasonStart": "04-16",
            "seasonEnd": "10-31"
          },
          {
            "label": "Đón khách mùa đông",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 480,
            "endMinutes": 1020,
            "endDayOffset": 0,
            "seasonStart": "11-01",
            "seasonEnd": "04-15"
          }
        ],
        "evidence": {
          "sourceIds": [
            "halong-hours"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Theo lịch quản lý công bố 06/11/2024; kiểm tra thông báo trước khi khởi hành."
          ],
          "unresolvedIssues": []
        },
        "notes": [
          "Lịch đón khách tại điểm, không phải giờ tàu xuất/về cảng. Tuân thủ điều tiết và thời tiết ngày đi."
        ],
        "status": "seasonal"
      },
      "notes": []
    },
    {
      "placeId": "ha-long/thien-cung",
      "visitScopeLabel": "Tham quan điểm trong hành trình vịnh; phí tuyến dùng chung, không phải vé lẻ hang",
      "price": {
        "evidence": {
          "sourceIds": [
            "halong-fees"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
            "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
          ],
          "unresolvedIssues": []
        },
        "options": [
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL1",
            "amountVnd": 250000,
            "id": "halong-vhl1-day",
            "packageId": "halong-vhl1-day",
            "label": "VHL1 ban ngày",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          }
        ],
        "status": "bundled"
      },
      "hours": {
        "rules": [
          {
            "label": "Đón khách mùa hè",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 450,
            "endMinutes": 1050,
            "endDayOffset": 0,
            "seasonStart": "04-16",
            "seasonEnd": "10-31"
          },
          {
            "label": "Đón khách mùa đông",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 450,
            "endMinutes": 1020,
            "endDayOffset": 0,
            "seasonStart": "11-01",
            "seasonEnd": "04-15"
          }
        ],
        "evidence": {
          "sourceIds": [
            "halong-hours"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Theo lịch quản lý công bố 06/11/2024; kiểm tra thông báo trước khi khởi hành."
          ],
          "unresolvedIssues": []
        },
        "notes": [
          "Lịch đón khách tại điểm, không phải giờ tàu xuất/về cảng. Tuân thủ điều tiết và thời tiết ngày đi."
        ],
        "status": "seasonal"
      },
      "notes": []
    },
    {
      "placeId": "ha-long/ga-choi",
      "visitScopeLabel": "Hòn Trống Mái (Gà Chọi): ngắm từ tàu trên tuyến 1 hoặc 5",
      "price": {
        "evidence": {
          "sourceIds": [
            "halong-fees",
            "halong-trong-mai"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Đây là phí tham quan vịnh, không phải báo giá trọn gói dịch vụ tàu. Đối chiếu dịch vụ và đối tượng miễn, giảm trước khi mua.",
            "Mức phí theo trang quản lý công bố 31/03/2025; lịch chuyến và thông báo điều tiết thực tế cần kiểm tra trước đi."
          ],
          "unresolvedIssues": []
        },
        "options": [
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL1",
            "amountVnd": 250000,
            "id": "halong-vhl1-day",
            "packageId": "halong-vhl1-day",
            "label": "VHL1 ban ngày",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Xác nhận đúng tuyến và thời gian lưu trú; không cộng lại cùng phí tuyến ở từng địa điểm."
            ],
            "included": [],
            "routeId": "VHL5",
            "amountVnd": 250000,
            "id": "halong-vhl5-day",
            "packageId": "halong-vhl5-day",
            "label": "VHL5 tới Gia Luận",
            "unit": "người/lần/tuyến",
            "audience": "Khách áp dụng mức phí cơ bản trong biểu phí",
            "excluded": [],
            "currency": "VND"
          }
        ],
        "status": "bundled"
      },
      "hours": {
        "rules": [],
        "evidence": {
          "sourceIds": [
            "halong-trong-mai"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Không thay giờ chuyến tàu bằng giờ mở cửa cố định của hòn đảo. Xác nhận hành trình với đơn vị tàu."
          ],
          "unresolvedIssues": []
        },
        "notes": [
          "Thời điểm tàu đi qua theo lịch chuyến thuộc tuyến 1 hoặc 5. Nguồn mô tả ngắm từ tàu, không công bố một khung giờ vào hòn đảo riêng."
        ],
        "status": "event_based"
      },
      "notes": []
    },
    {
      "placeId": "ha-long/tuan-chau",
      "visitScopeLabel": "Các gói vui chơi Tuần Châu Park trên đảo; không phải phí vào toàn đảo, cảng hoặc phà",
      "price": {
        "evidence": {
          "sourceIds": [
            "tuan-park4",
            "tuan-park3"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Chỉ áp dụng các gói/đối tượng đã nêu; chính sách miễn/giảm của nhóm khác cần xác nhận tại cổng đặt vé.",
            "Giá gói 3 kèm đồ uống khác gói 100.000đ trong bài cũ. Không dùng các combo ẩm thực đã ghi hết hạn 31/08/2026."
          ],
          "unresolvedIssues": []
        },
        "options": [
          {
            "conditions": [
              "Đối chiếu chính sách chiều cao trước khi mua."
            ],
            "included": [],
            "amountVnd": 300000,
            "id": "park4-adult",
            "packageId": "tuan-park4",
            "label": "Combo 4 công viên",
            "unit": "người/ngày đã chọn",
            "audience": "Vé người lớn theo cổng đặt vé",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Đúng gói kèm đồ uống trên trang đặt vé."
            ],
            "included": [
              "1 đồ uống tại Lakeside Coffee"
            ],
            "amountVnd": 150000,
            "id": "park3-adult",
            "packageId": "tuan-park3-drink",
            "label": "Combo 3 công viên + 1 đồ uống",
            "unit": "người/ngày đã chọn",
            "audience": "Người lớn",
            "excluded": [],
            "currency": "VND"
          },
          {
            "conditions": [
              "Không tự áp chính sách trẻ em của gói khác hoặc khuyến mại cũ."
            ],
            "included": [],
            "amountVnd": 50000,
            "id": "park3-child",
            "packageId": "tuan-park3-drink",
            "label": "Combo 3 công viên",
            "unit": "người/ngày đã chọn",
            "audience": "Trẻ em cao 80–100 cm",
            "excluded": [],
            "currency": "VND"
          }
        ],
        "status": "bundled"
      },
      "hours": {
        "rules": [
          {
            "label": "King Kong Park",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 480,
            "endMinutes": 1020,
            "endDayOffset": 0,
            "effectiveFrom": "2026-05-04"
          },
          {
            "label": "Tuần Châu Farm — ca sáng",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 480,
            "endMinutes": 660,
            "endDayOffset": 0,
            "effectiveFrom": "2026-05-04"
          },
          {
            "label": "Tuần Châu Farm — ca chiều",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 810,
            "endMinutes": 1020,
            "endDayOffset": 0,
            "effectiveFrom": "2026-05-04"
          },
          {
            "label": "Farm Hill — ca sáng",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 510,
            "endMinutes": 660,
            "endDayOffset": 0,
            "effectiveFrom": "2026-05-04"
          },
          {
            "label": "Farm Hill — ca chiều",
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "startMinutes": 810,
            "endMinutes": 1020,
            "endDayOffset": 0,
            "effectiveFrom": "2026-05-04"
          }
        ],
        "evidence": {
          "sourceIds": [
            "tuan-hours",
            "tuan-guide"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "reviewed",
          "conditions": [
            "Lịch áp dụng từ 04/05/2026 đến khi có thông báo mới; mỗi phân khu có lịch riêng."
          ],
          "unresolvedIssues": []
        },
        "notes": [
          "Show cá heo và hải cẩu: suất 10:00 và 15:00; nên đến trước 30 phút. Nguồn không nêu giờ kết thúc từng suất.",
          "Farm nghỉ 11:00–13:30. Lịch có thể thay đổi vì thời tiết và tình hình thực tế."
        ],
        "status": "scheduled"
      },
      "notes": []
    },
    {
      "placeId": "sa-pa/fansipan",
      "visitScopeLabel": "Fansipan",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "sa-pa/cat-cat",
      "visitScopeLabel": "Bản Cát Cát",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "sa-pa/ta-phin",
      "visitScopeLabel": "Bản Tả Phìn",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "sa-pa/bac-ha",
      "visitScopeLabel": "Chợ Bắc Hà",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "sa-pa/muong-hum",
      "visitScopeLabel": "Chợ Mường Hum",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "sa-pa/sapa-napro",
      "visitScopeLabel": "SAPANAPRO, Tả Phìn",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ninh-binh/hang-mua",
      "visitScopeLabel": "Hang Múa",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ninh-binh/tam-coc",
      "visitScopeLabel": "Tam Cốc",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ninh-binh/trang-an",
      "visitScopeLabel": "Tràng An",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ninh-binh/hoa-lu",
      "visitScopeLabel": "Cố đô Hoa Lư",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ninh-binh/van-long",
      "visitScopeLabel": "Đầm Vân Long",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ninh-binh/bai-dinh",
      "visitScopeLabel": "Chùa Bái Đính",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "hue/citadel",
      "visitScopeLabel": "Khu tham quan Đại Nội Huế có vé; không phải phí đi lại toàn bộ Kinh thành Huế",
      "price": {
        "status": "priced",
        "options": [
          {
            "included": [
              "Tham quan một điểm đã chọn"
            ],
            "unit": "người/lượt",
            "excluded": [],
            "label": "Vé lẻ",
            "audience": "Người lớn theo bảng phí",
            "currency": "VND",
            "id": "single-adult",
            "amountVnd": 200000,
            "conditions": [
              "Mức vé lẻ trong bảng áp dụng từ 02/06/2026."
            ]
          },
          {
            "included": [],
            "unit": "người/lượt",
            "excluded": [],
            "label": "Vé lẻ trẻ em",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "id": "single-child",
            "amountVnd": 40000,
            "conditions": [
              "Theo đúng nhóm tuổi trong bảng phí; không tự suy mức miễn/giảm cho nhóm khác."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-dn-mm-kd",
            "id": "hue-dn-mm-kd-adult",
            "amountVnd": 420000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-dn-mm-kd",
            "id": "hue-dn-mm-kd-child",
            "amountVnd": 80000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Tự Đức",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-dn-mm-td",
            "id": "hue-dn-mm-td-adult",
            "amountVnd": 420000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Tự Đức",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-dn-mm-td",
            "id": "hue-dn-mm-td-child",
            "amountVnd": 80000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Tự Đức + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-dn-td-kd",
            "id": "hue-dn-td-kd-adult",
            "amountVnd": 420000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Tự Đức + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-dn-td-kd",
            "id": "hue-dn-td-kd-child",
            "amountVnd": 80000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Tự Đức + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-four",
            "id": "hue-four-adult",
            "amountVnd": 530000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Tự Đức + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-four",
            "id": "hue-four-child",
            "amountVnd": 100000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Tuyến gộp tất cả điểm di tích theo bảng phí",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-all",
            "id": "hue-all-adult",
            "amountVnd": 600000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Tuyến gộp tất cả điểm di tích theo bảng phí",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-all",
            "id": "hue-all-child",
            "amountVnd": 120000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          }
        ],
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Vé lẻ từ 02/06/2026; bảng tuyến từ 04/01/2026. Nhóm miễn/giảm, ngày ưu đãi cần kiểm tra quy định trước khi mua. Không suy chính sách miễn trẻ em ở di tích khác áp dụng cho bốn điểm này."
          ],
          "unresolvedIssues": [],
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hue-fees-2026"
          ]
        }
      },
      "hours": {
        "status": "seasonal",
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Khung giờ do cổng vé Trung tâm công bố, không dùng giờ bán vé làm giờ đóng cửa; kiểm tra thông báo đặc biệt tại ngày đi."
          ],
          "unresolvedIssues": [],
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hue-time",
            "hue-rules"
          ]
        },
        "rules": [
          {
            "endMinutes": 1110,
            "seasonEnd": "10-15",
            "startMinutes": 390,
            "endDayOffset": 0,
            "admissionCutoffMinutes": 1050,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "seasonStart": "03-16",
            "label": "Mùa hè — giờ tham quan, tách hạn bán vé"
          },
          {
            "endMinutes": 1080,
            "seasonEnd": "03-15",
            "startMinutes": 420,
            "endDayOffset": 0,
            "admissionCutoffMinutes": 1020,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "seasonStart": "10-16",
            "label": "Mùa đông — giờ tham quan, tách hạn bán vé"
          }
        ],
        "notes": [
          "Nguồn ghi đóng cửa ngừng phục vụ sau 60 phút kể từ khi kết thúc bán vé. Mốc nhận khách trong hồ sơ là hạn bán vé theo nguồn; xác nhận yêu cầu kiểm soát cổng trước khi đi.",
          "Lịch lễ hội/chương trình đêm nếu có là thông báo riêng. Mặc trang phục lịch sự ở nội điện, giữ yên lặng và tuân thủ nội quy."
        ]
      },
      "notes": []
    },
    {
      "placeId": "hue/tu-duc",
      "visitScopeLabel": "Lăng Tự Đức",
      "price": {
        "status": "priced",
        "options": [
          {
            "included": [
              "Tham quan một điểm đã chọn"
            ],
            "unit": "người/lượt",
            "excluded": [],
            "label": "Vé lẻ",
            "audience": "Người lớn theo bảng phí",
            "currency": "VND",
            "id": "single-adult",
            "amountVnd": 150000,
            "conditions": [
              "Mức vé lẻ trong bảng áp dụng từ 02/06/2026."
            ]
          },
          {
            "included": [],
            "unit": "người/lượt",
            "excluded": [],
            "label": "Vé lẻ trẻ em",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "id": "single-child",
            "amountVnd": 30000,
            "conditions": [
              "Theo đúng nhóm tuổi trong bảng phí; không tự suy mức miễn/giảm cho nhóm khác."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Tự Đức + Đồng Khánh",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-td-dk",
            "id": "hue-td-dk-adult",
            "amountVnd": 200000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Tự Đức + Đồng Khánh",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-td-dk",
            "id": "hue-td-dk-child",
            "amountVnd": 30000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Tự Đức",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-dn-mm-td",
            "id": "hue-dn-mm-td-adult",
            "amountVnd": 420000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Tự Đức",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-dn-mm-td",
            "id": "hue-dn-mm-td-child",
            "amountVnd": 80000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Tự Đức + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-dn-td-kd",
            "id": "hue-dn-td-kd-adult",
            "amountVnd": 420000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Tự Đức + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-dn-td-kd",
            "id": "hue-dn-td-kd-child",
            "amountVnd": 80000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Tự Đức + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-four",
            "id": "hue-four-adult",
            "amountVnd": 530000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Tự Đức + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-four",
            "id": "hue-four-child",
            "amountVnd": 100000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Tuyến gộp tất cả điểm di tích theo bảng phí",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-all",
            "id": "hue-all-adult",
            "amountVnd": 600000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Tuyến gộp tất cả điểm di tích theo bảng phí",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-all",
            "id": "hue-all-child",
            "amountVnd": 120000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          }
        ],
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Vé lẻ từ 02/06/2026; bảng tuyến từ 04/01/2026. Nhóm miễn/giảm, ngày ưu đãi cần kiểm tra quy định trước khi mua. Không suy chính sách miễn trẻ em ở di tích khác áp dụng cho bốn điểm này."
          ],
          "unresolvedIssues": [],
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hue-fees-2026"
          ]
        }
      },
      "hours": {
        "status": "seasonal",
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Khung giờ do cổng vé Trung tâm công bố, không dùng giờ bán vé làm giờ đóng cửa; kiểm tra thông báo đặc biệt tại ngày đi."
          ],
          "unresolvedIssues": [],
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hue-time",
            "hue-rules"
          ]
        },
        "rules": [
          {
            "endMinutes": 1110,
            "seasonEnd": "10-15",
            "startMinutes": 390,
            "endDayOffset": 0,
            "admissionCutoffMinutes": 1050,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "seasonStart": "03-16",
            "label": "Mùa hè — giờ tham quan, tách hạn bán vé"
          },
          {
            "endMinutes": 1080,
            "seasonEnd": "03-15",
            "startMinutes": 420,
            "endDayOffset": 0,
            "admissionCutoffMinutes": 1020,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "seasonStart": "10-16",
            "label": "Mùa đông — giờ tham quan, tách hạn bán vé"
          }
        ],
        "notes": [
          "Nguồn ghi đóng cửa ngừng phục vụ sau 60 phút kể từ khi kết thúc bán vé. Mốc nhận khách trong hồ sơ là hạn bán vé theo nguồn; xác nhận yêu cầu kiểm soát cổng trước khi đi.",
          "Lịch lễ hội/chương trình đêm nếu có là thông báo riêng. Mặc trang phục lịch sự ở nội điện, giữ yên lặng và tuân thủ nội quy."
        ]
      },
      "notes": []
    },
    {
      "placeId": "hue/minh-mang",
      "visitScopeLabel": "Lăng Minh Mạng",
      "price": {
        "status": "priced",
        "options": [
          {
            "included": [
              "Tham quan một điểm đã chọn"
            ],
            "unit": "người/lượt",
            "excluded": [],
            "label": "Vé lẻ",
            "audience": "Người lớn theo bảng phí",
            "currency": "VND",
            "id": "single-adult",
            "amountVnd": 150000,
            "conditions": [
              "Mức vé lẻ trong bảng áp dụng từ 02/06/2026."
            ]
          },
          {
            "included": [],
            "unit": "người/lượt",
            "excluded": [],
            "label": "Vé lẻ trẻ em",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "id": "single-child",
            "amountVnd": 30000,
            "conditions": [
              "Theo đúng nhóm tuổi trong bảng phí; không tự suy mức miễn/giảm cho nhóm khác."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Minh Mạng + Gia Long",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-mm-gl",
            "id": "hue-mm-gl-adult",
            "amountVnd": 240000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Minh Mạng + Gia Long",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-mm-gl",
            "id": "hue-mm-gl-child",
            "amountVnd": 30000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-dn-mm-kd",
            "id": "hue-dn-mm-kd-adult",
            "amountVnd": 420000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-dn-mm-kd",
            "id": "hue-dn-mm-kd-child",
            "amountVnd": 80000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Tự Đức",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-dn-mm-td",
            "id": "hue-dn-mm-td-adult",
            "amountVnd": 420000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Tự Đức",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-dn-mm-td",
            "id": "hue-dn-mm-td-child",
            "amountVnd": 80000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Tự Đức + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-four",
            "id": "hue-four-adult",
            "amountVnd": 530000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Tự Đức + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-four",
            "id": "hue-four-child",
            "amountVnd": 100000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Tuyến gộp tất cả điểm di tích theo bảng phí",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-all",
            "id": "hue-all-adult",
            "amountVnd": 600000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Tuyến gộp tất cả điểm di tích theo bảng phí",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-all",
            "id": "hue-all-child",
            "amountVnd": 120000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          }
        ],
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Vé lẻ từ 02/06/2026; bảng tuyến từ 04/01/2026. Nhóm miễn/giảm, ngày ưu đãi cần kiểm tra quy định trước khi mua. Không suy chính sách miễn trẻ em ở di tích khác áp dụng cho bốn điểm này."
          ],
          "unresolvedIssues": [],
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hue-fees-2026"
          ]
        }
      },
      "hours": {
        "status": "seasonal",
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Khung giờ do cổng vé Trung tâm công bố, không dùng giờ bán vé làm giờ đóng cửa; kiểm tra thông báo đặc biệt tại ngày đi."
          ],
          "unresolvedIssues": [],
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hue-time",
            "hue-rules"
          ]
        },
        "rules": [
          {
            "endMinutes": 1110,
            "seasonEnd": "10-15",
            "startMinutes": 390,
            "endDayOffset": 0,
            "admissionCutoffMinutes": 1050,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "seasonStart": "03-16",
            "label": "Mùa hè — giờ tham quan, tách hạn bán vé"
          },
          {
            "endMinutes": 1080,
            "seasonEnd": "03-15",
            "startMinutes": 420,
            "endDayOffset": 0,
            "admissionCutoffMinutes": 1020,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "seasonStart": "10-16",
            "label": "Mùa đông — giờ tham quan, tách hạn bán vé"
          }
        ],
        "notes": [
          "Nguồn ghi đóng cửa ngừng phục vụ sau 60 phút kể từ khi kết thúc bán vé. Mốc nhận khách trong hồ sơ là hạn bán vé theo nguồn; xác nhận yêu cầu kiểm soát cổng trước khi đi.",
          "Lịch lễ hội/chương trình đêm nếu có là thông báo riêng. Mặc trang phục lịch sự ở nội điện, giữ yên lặng và tuân thủ nội quy."
        ]
      },
      "notes": []
    },
    {
      "placeId": "hue/khai-dinh",
      "visitScopeLabel": "Lăng Khải Định",
      "price": {
        "status": "priced",
        "options": [
          {
            "included": [
              "Tham quan một điểm đã chọn"
            ],
            "unit": "người/lượt",
            "excluded": [],
            "label": "Vé lẻ",
            "audience": "Người lớn theo bảng phí",
            "currency": "VND",
            "id": "single-adult",
            "amountVnd": 150000,
            "conditions": [
              "Mức vé lẻ trong bảng áp dụng từ 02/06/2026."
            ]
          },
          {
            "included": [],
            "unit": "người/lượt",
            "excluded": [],
            "label": "Vé lẻ trẻ em",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "id": "single-child",
            "amountVnd": 30000,
            "conditions": [
              "Theo đúng nhóm tuổi trong bảng phí; không tự suy mức miễn/giảm cho nhóm khác."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-dn-mm-kd",
            "id": "hue-dn-mm-kd-adult",
            "amountVnd": 420000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-dn-mm-kd",
            "id": "hue-dn-mm-kd-child",
            "amountVnd": 80000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Tự Đức + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-dn-td-kd",
            "id": "hue-dn-td-kd-adult",
            "amountVnd": 420000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Tự Đức + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-dn-td-kd",
            "id": "hue-dn-td-kd-child",
            "amountVnd": 80000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Đại Nội + Minh Mạng + Tự Đức + Khải Định",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-four",
            "id": "hue-four-adult",
            "amountVnd": 530000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Đại Nội + Minh Mạng + Tự Đức + Khải Định",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-four",
            "id": "hue-four-child",
            "amountVnd": 100000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói Tuyến gộp tất cả điểm di tích theo bảng phí",
            "audience": "Người lớn",
            "currency": "VND",
            "packageId": "hue-all",
            "id": "hue-all-adult",
            "amountVnd": 600000,
            "conditions": [
              "Chọn thay cho vé lẻ của cùng tuyến, không cộng cùng phí nhiều lần."
            ]
          },
          {
            "included": [],
            "unit": "người/tuyến",
            "excluded": [],
            "label": "Gói trẻ em Tuyến gộp tất cả điểm di tích theo bảng phí",
            "audience": "Trẻ em từ 7 đến 12 tuổi",
            "currency": "VND",
            "packageId": "hue-all",
            "id": "hue-all-child",
            "amountVnd": 120000,
            "conditions": [
              "Đối chiếu tuổi, thời hạn và quyền lợi tại nơi đặt vé."
            ]
          }
        ],
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Vé lẻ từ 02/06/2026; bảng tuyến từ 04/01/2026. Nhóm miễn/giảm, ngày ưu đãi cần kiểm tra quy định trước khi mua. Không suy chính sách miễn trẻ em ở di tích khác áp dụng cho bốn điểm này."
          ],
          "unresolvedIssues": [],
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hue-fees-2026"
          ]
        }
      },
      "hours": {
        "status": "seasonal",
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Khung giờ do cổng vé Trung tâm công bố, không dùng giờ bán vé làm giờ đóng cửa; kiểm tra thông báo đặc biệt tại ngày đi."
          ],
          "unresolvedIssues": [],
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hue-time",
            "hue-rules"
          ]
        },
        "rules": [
          {
            "endMinutes": 1110,
            "seasonEnd": "10-15",
            "startMinutes": 390,
            "endDayOffset": 0,
            "admissionCutoffMinutes": 1050,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "seasonStart": "03-16",
            "label": "Mùa hè — giờ tham quan, tách hạn bán vé"
          },
          {
            "endMinutes": 1080,
            "seasonEnd": "03-15",
            "startMinutes": 420,
            "endDayOffset": 0,
            "admissionCutoffMinutes": 1020,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "seasonStart": "10-16",
            "label": "Mùa đông — giờ tham quan, tách hạn bán vé"
          }
        ],
        "notes": [
          "Nguồn ghi đóng cửa ngừng phục vụ sau 60 phút kể từ khi kết thúc bán vé. Mốc nhận khách trong hồ sơ là hạn bán vé theo nguồn; xác nhận yêu cầu kiểm soát cổng trước khi đi.",
          "Lịch lễ hội/chương trình đêm nếu có là thông báo riêng. Mặc trang phục lịch sự ở nội điện, giữ yên lặng và tuân thủ nội quy."
        ]
      },
      "notes": []
    },
    {
      "placeId": "hue/dong-ba",
      "visitScopeLabel": "Chợ Đông Ba",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [
            "hue-dongba-directory"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Hồ sơ Huetripo nêu 06:30–19:00 nhưng chưa đối chiếu đủ lịch theo ngày/phân khu với quản lý chợ."
          ]
        }
      },
      "notes": [
        "Lịch từng quầy và khu chợ đêm có thể khác khối chợ chính; xác nhận trước khi đi. Không dùng giá món hàng trên cổng du lịch thành vé tham quan."
      ]
    },
    {
      "placeId": "hue/thien-mu",
      "visitScopeLabel": "Chùa Thiên Mụ",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": [
        "Chưa đối chiếu đủ phí và lịch đón khách với đơn vị quản lý chùa. Không áp bảng giờ bán vé các di tích khác làm giờ tham quan chùa."
      ]
    },
    {
      "placeId": "da-nang/my-khe",
      "visitScopeLabel": "Biển Mỹ Khê",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": "2026-10-20",
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đọc được nguồn quản lý đủ để duyệt phí/miễn phí; không tự lấy giá dịch vụ biển làm vé vào bãi."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": "2026-10-20",
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa xác nhận lịch tắm/giờ cứu hộ hoặc giới hạn tiếp cận từ nguồn quản lý; tuân thủ cờ, biển báo và hướng dẫn tại bãi. Không mặc định24/7."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "da-nang/marble",
      "visitScopeLabel": "Ngũ Hành Sơn — Thủy Sơn, động Âm Phủ và thang máy có phí riêng",
      "price": {
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Phí tham quan và thang máy tách riêng. Trang quản lý ghi ngày18/06/2014; đối chiếu nội dung với bảng du lịch22/01/2026, không suy đó là ngày hiệu lực của mọi mức giá.",
            "Nguồn2026 gọi đây là mức tham khảo; ngày miễn/giảm đặc biệt và giấy tờ cần kiểm tra tại quầy."
          ],
          "sourceIds": [
            "marble-management",
            "danang-fees-2026"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": []
        },
        "options": [
          {
            "amountVnd": 40000,
            "unit": "người/lần",
            "label": "Vé Thủy Sơn",
            "excluded": [
              "Vé động Âm Phủ, vé thang máy"
            ],
            "conditions": [
              "Mua ở cổng 01 hoặc 02 theo hướng dẫn Ban quản lý."
            ],
            "currency": "VND",
            "audience": "Người lớn",
            "included": [
              "Tham quan Thủy Sơn"
            ],
            "id": "thuy-son-adult"
          },
          {
            "amountVnd": 10000,
            "unit": "người/lần",
            "label": "Vé Thủy Sơn học sinh/sinh viên",
            "excluded": [
              "Vé động Âm Phủ, vé thang máy"
            ],
            "conditions": [
              "Chuẩn bị giấy tờ chứng minh đối tượng và kiểm tra yêu cầu tại quầy."
            ],
            "currency": "VND",
            "audience": "Học sinh, sinh viên",
            "included": [
              "Tham quan Thủy Sơn"
            ],
            "id": "thuy-son-student"
          },
          {
            "amountVnd": 0,
            "unit": "người/lần",
            "label": "Miễn vé Thủy Sơn theo tuổi",
            "excluded": [],
            "conditions": [
              "Chỉ nhóm dưới 6 tuổi theo bảng nguồn."
            ],
            "currency": "VND",
            "audience": "Trẻ em dưới 6 tuổi",
            "included": [
              "Tham quan Thủy Sơn"
            ],
            "id": "thuy-son-under-six"
          },
          {
            "amountVnd": 20000,
            "unit": "người/lần",
            "label": "Vé động Âm Phủ — mua riêng nếu chọn tham quan",
            "excluded": [
              "Vé Thủy Sơn, thang máy"
            ],
            "conditions": [],
            "currency": "VND",
            "audience": "Người lớn",
            "included": [
              "Động Âm Phủ"
            ],
            "id": "am-phu-adult"
          },
          {
            "amountVnd": 7000,
            "unit": "người/lần",
            "label": "Vé động Âm Phủ học sinh/sinh viên",
            "excluded": [
              "Vé Thủy Sơn, thang máy"
            ],
            "conditions": [
              "Đối chiếu giấy tờ tại quầy."
            ],
            "currency": "VND",
            "audience": "Học sinh, sinh viên",
            "included": [
              "Động Âm Phủ"
            ],
            "id": "am-phu-student"
          },
          {
            "amountVnd": 0,
            "unit": "người/lần",
            "label": "Miễn vé động Âm Phủ theo tuổi",
            "excluded": [],
            "conditions": [],
            "currency": "VND",
            "audience": "Trẻ em dưới 6 tuổi",
            "included": [
              "Động Âm Phủ"
            ],
            "id": "am-phu-under-six"
          },
          {
            "amountVnd": 15000,
            "unit": "người/lượt",
            "label": "Thang máy một lượt — dịch vụ tùy chọn",
            "excluded": [
              "Vé tham quan"
            ],
            "conditions": [
              "Mua thêm khi dùng; không cộng cả vé một lượt và khứ hồi cho cùng lựa chọn."
            ],
            "currency": "VND",
            "audience": "Người lớn, học sinh, sinh viên",
            "included": [
              "Một lượt thang máy"
            ],
            "id": "lift-one-way"
          },
          {
            "amountVnd": 30000,
            "unit": "người/khứ hồi",
            "label": "Thang máy khứ hồi — dịch vụ tùy chọn",
            "excluded": [
              "Vé tham quan"
            ],
            "conditions": [
              "Nguồn du lịch2026 ghi mức khứ hồi."
            ],
            "currency": "VND",
            "audience": "Người dùng dịch vụ theo bảng giá",
            "included": [
              "Thang máy khứ hồi"
            ],
            "id": "lift-return"
          },
          {
            "amountVnd": 0,
            "unit": "người/lượt",
            "label": "Miễn dịch vụ thang máy theo tuổi",
            "excluded": [
              "Các dịch vụ khác"
            ],
            "conditions": [],
            "currency": "VND",
            "audience": "Trẻ em dưới 6 tuổi",
            "included": [
              "Thang máy"
            ],
            "id": "lift-under-six"
          }
        ],
        "status": "priced"
      },
      "hours": {
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Kiểm tra thông báo vận hành hoặc thời tiết tại ngày đi."
          ],
          "sourceIds": [
            "marble-management",
            "danang-fees-2026"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": []
        },
        "notes": [
          "Giờ phục vụ theo Ban quản lý và bảng du lịch2026; không coi đây là giờ nhận lượt thang máy cuối."
        ],
        "status": "scheduled",
        "rules": [
          {
            "label": "Hằng ngày theo Ban quản lý",
            "startMinutes": 420,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "endDayOffset": 0,
            "endMinutes": 1020
          }
        ]
      },
      "notes": [
        "Chọn khu và dịch vụ cần dùng, không coi tất cả mức giá dưới đây là một combo bắt buộc."
      ]
    },
    {
      "placeId": "da-nang/son-tra",
      "visitScopeLabel": "Sơn Trà — tham quan cảnh quan trên ba tuyến được phép, ngoài cơ sở thu phí riêng",
      "price": {
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Bảng nguồn áp dụng từ01/01/2023, chưa ghi ngày chỉnh sửa mới trên trang; xác nhận chính sách tại điểm trước chuyến đi."
          ],
          "sourceIds": [
            "danang-fees-2023"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": []
        },
        "options": [
          {
            "amountVnd": 0,
            "unit": "người",
            "label": "Tham quan cảnh quan theo nguồn du lịch",
            "excluded": [
              "Bảo tàng Đồng Đình, điểm dịch vụ riêng, tour, xe và đồ uống"
            ],
            "conditions": [
              "Nguồn bảng giá2023 ghi miễn phí; không phải gói miễn phí mọi cơ sở trên bán đảo."
            ],
            "currency": "VND",
            "audience": "Du khách tham quan cảnh quan chung",
            "included": [
              "Cảnh quan chung bán đảo"
            ],
            "id": "landscape-entry"
          }
        ],
        "status": "free"
      },
      "hours": {
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Giờ là khung được phép tham quan ba tuyến; không suy đó là giờ khởi hành cuối hoặc giờ mở riêng từng cơ sở."
          ],
          "sourceIds": [
            "sontra-route-rules"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": []
        },
        "notes": [
          "Áp dụng các tuyến Hoàng Sa–Cây Đa, Yết Kiêu–Đỉnh Bàn Cờ–Bãi Bắc, Yết Kiêu–Suối Ôm; không áp lịch này cho toàn bộ khách sạn, chùa hay cơ sở khác.",
          "Có trạm kiểm soát; ngoài giờ rào chắn đóng. Không đi tuyến nhánh bị hạn chế. Các tuyến nêu trong nguồn loại trừ xe tay ga và ô tô trên24 chỗ; đoạn Đỉnh Bàn Cờ–Bãi Bắc một chiều theo hướng nguồn quy định.",
          "Giữ khoảng cách với động vật, không cho ăn hoặc gây tiếng ồn; tuân theo hướng dẫn tại trạm và thông báo thời tiết."
        ],
        "status": "seasonal",
        "rules": [
          {
            "seasonStart": "03-01",
            "seasonEnd": "09-30",
            "startMinutes": 450,
            "endDayOffset": 0,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "endMinutes": 1110,
            "label": "Ba tuyến — tháng3 đến hết tháng9"
          },
          {
            "seasonStart": "10-01",
            "seasonEnd": "02-29",
            "startMinutes": 450,
            "endDayOffset": 0,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "endMinutes": 1050,
            "label": "Ba tuyến — tháng10 đến hết tháng2"
          }
        ]
      },
      "notes": []
    },
    {
      "placeId": "da-nang/lady-buddha",
      "visitScopeLabel": "Tượng Quan Thế Âm — khu tham quan chùa Linh Ứng Bãi Bụt, Sơn Trà",
      "price": {
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Bảng du lịch2023 ghi miễn phí; kiểm tra thông báo tại chùa trước đi. Không dùng sự im lặng của nguồn về giá làm bằng chứng miễn phí."
          ],
          "sourceIds": [
            "danang-fees-2023"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": []
        },
        "options": [
          {
            "amountVnd": 0,
            "unit": "người",
            "label": "Vào tham quan chùa theo nguồn du lịch",
            "excluded": [
              "Dịch vụ mua riêng, khu hạn chế hoặc mọi tầng bên trong tượng"
            ],
            "conditions": [
              "Không phải chùa Linh Ứng tại Bà Nà hoặc Ngũ Hành Sơn."
            ],
            "currency": "VND",
            "audience": "Khách tham quan chùa Linh Ứng Bãi Bụt",
            "included": [
              "Khu tham quan chùa theo hướng dẫn tại chỗ"
            ],
            "id": "pagoda-admission"
          }
        ],
        "status": "free"
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "reviewState": "unverified",
          "conditions": [],
          "sourceIds": [
            "danang-fees-2023",
            "linhung-visitor-rules"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": [
            "Nguồn du lịch2023 ghi08:00–17:00 nhưng các bài hướng dẫn khác ghi06:00–21:00; trang chùa chưa đọc được thông báo xác nhận giờ. Vui lòng kiểm tra với chùa trước khi đến."
          ]
        }
      },
      "notes": [
        "Theo nội quy chùa: đỗ xe đúng nơi hướng dẫn; trang phục kín đáo, giữ yên tĩnh, không chạm/hư hại cảnh quan hoặc tượng. Không suy có thể vào mọi tầng của tượng."
      ]
    },
    {
      "placeId": "da-nang/hai-van",
      "visitScopeLabel": "Đèo Hải Vân — ngắm cảnh đường đèo, không bao gồm di tích Hải Vân Quan",
      "price": {
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Phạm vi chỉ cảnh quan đường đèo theo bài01/08/2025."
          ],
          "sourceIds": [
            "haivan-landscape"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": []
        },
        "options": [
          {
            "amountVnd": 0,
            "unit": "người",
            "label": "Ngắm cảnh thiên nhiên trên đường đèo",
            "excluded": [
              "Vé Hải Vân Quan, vận chuyển, hầm, gửi xe, quán và dịch vụ riêng"
            ],
            "conditions": [
              "Nguồn du lịch xác nhận ngắm cảnh miễn phí; không suy phí di tích Hải Vân Quan từ phí đường đèo."
            ],
            "currency": "VND",
            "audience": "Khách tự tham quan cảnh quan",
            "included": [
              "Ngắm cảnh đường đèo"
            ],
            "id": "landscape"
          }
        ],
        "status": "free"
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [
          "Nguồn khuyên tránh trời tối, mưa bão và sương mù; giờ gợi ý ngắm cảnh không phải giờ mở cửa được xác minh."
        ],
        "evidence": {
          "reviewState": "unverified",
          "conditions": [],
          "sourceIds": [
            "haivan-landscape"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": [
            "Nguồn chỉ khuyên thời điểm đi, chưa xác nhận khung giờ vận hành/điều tiết đường; không mặc định24/7."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "da-nang/han-market",
      "visitScopeLabel": "Chợ Hàn",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "reviewState": "unverified",
          "conditions": [],
          "sourceIds": [
            "han-market-reference"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": [
            "Chưa có nguồn xác nhận phí/miễn phí vào chợ; giá món ăn, hàng hóa, tour và gửi xe không phải giá vé tham quan."
          ]
        }
      },
      "hours": {
        "evidence": {
          "reviewState": "reviewed",
          "conditions": [
            "Bài giới thiệu nêu khung giờ chung, không có lịch theo từng thứ/ngày lễ. Xác nhận lịch quầy trước khi ghé; không lấy giờ quán cà phê riêng làm giờ toàn chợ."
          ],
          "sourceIds": [
            "han-market-reference"
          ],
          "checkedAt": "2026-10-20",
          "unresolvedIssues": []
        },
        "notes": [
          "Nguồn du lịch12/06/2026 ghi giờ tham khảo06:00–19:00; giờ từng quầy và ngày đặc biệt có thể khác. Không phải cam kết mọi gian hàng mở suốt khung này."
        ],
        "status": "scheduled",
        "rules": [
          {
            "label": "Khung giờ tham khảo chung của chợ",
            "startMinutes": 360,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "endDayOffset": 0,
            "endMinutes": 1140
          }
        ]
      },
      "notes": []
    },
    {
      "placeId": "hoi-an/ancient-town",
      "visitScopeLabel": "Phố cổ Hội An — tham quan theo gói vé di sản",
      "price": {
        "options": [
          {
            "id": "heritage-80",
            "conditions": [
              "Mức tiền là cho gói, không phải vé lẻ riêng của địa điểm này. Kiểm tra còn ô phù hợp cho điểm muốn vào."
            ],
            "included": [],
            "currency": "VND",
            "label": "Gói vé phố cổ 80.000đ",
            "audience": "Chọn gói theo quyền lợi công bố",
            "amountVnd": 80000,
            "unit": "người/gói",
            "excluded": [],
            "packageId": "hoian-heritage-80"
          },
          {
            "id": "heritage-120",
            "conditions": [
              "Mức tiền là cho gói, không phải vé lẻ riêng của địa điểm này. Kiểm tra còn ô phù hợp cho điểm muốn vào."
            ],
            "included": [],
            "currency": "VND",
            "label": "Gói vé phố cổ 120.000đ",
            "audience": "Chọn gói theo quyền lợi công bố",
            "amountVnd": 120000,
            "unit": "người/gói",
            "excluded": [],
            "packageId": "hoian-heritage-120"
          }
        ],
        "status": "bundled",
        "evidence": {
          "conditions": [
            "Giá/quyền lợi dùng thông tin 16/03/2026; danh mục cũ chỉ đối chiếu tên điểm, không dùng giá theo quốc tịch hay lịch cũ."
          ],
          "unresolvedIssues": [],
          "reviewState": "reviewed",
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hoian-fees-2026",
            "hoian-ticket-sites"
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [
          "Nguồn mô tả phố đi bộ 09:00–21:30 mùa hè, 09:00–21:00 mùa đông; riêng Phan Châu Trinh bắt đầu 17:30. Đây là giờ điều tiết phố đi bộ, không phải lịch mở từng di tích."
        ],
        "evidence": {
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đầy đủ mốc chuyển mùa và khung giờ tham quan theo phạm vi vé; không tự áp lịch phố đi bộ cho tất cả công trình."
          ],
          "reviewState": "unverified",
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hoian-fees-2026"
          ]
        }
      },
      "notes": [
        "Giá có nguồn tham khảo tại ngày kiểm tra; kiểm tra thông báo và quyền lợi khi mua vé."
      ]
    },
    {
      "placeId": "hoi-an/japanese-bridge",
      "visitScopeLabel": "Chùa Cầu — chọn điểm trong ô vé phố cổ",
      "price": {
        "options": [
          {
            "id": "heritage-80",
            "conditions": [
              "Mức tiền là cho gói, không phải vé lẻ riêng của địa điểm này. Kiểm tra còn ô phù hợp cho điểm muốn vào."
            ],
            "included": [],
            "currency": "VND",
            "label": "Gói vé phố cổ 80.000đ",
            "audience": "Chọn gói theo quyền lợi công bố",
            "amountVnd": 80000,
            "unit": "người/gói",
            "excluded": [],
            "packageId": "hoian-heritage-80"
          },
          {
            "id": "heritage-120",
            "conditions": [
              "Mức tiền là cho gói, không phải vé lẻ riêng của địa điểm này. Kiểm tra còn ô phù hợp cho điểm muốn vào."
            ],
            "included": [],
            "currency": "VND",
            "label": "Gói vé phố cổ 120.000đ",
            "audience": "Chọn gói theo quyền lợi công bố",
            "amountVnd": 120000,
            "unit": "người/gói",
            "excluded": [],
            "packageId": "hoian-heritage-120"
          }
        ],
        "status": "bundled",
        "evidence": {
          "conditions": [
            "Giá/quyền lợi dùng thông tin 16/03/2026; danh mục cũ chỉ đối chiếu tên điểm, không dùng giá theo quốc tịch hay lịch cũ."
          ],
          "unresolvedIssues": [],
          "reviewState": "reviewed",
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hoian-fees-2026",
            "hoian-ticket-sites"
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [
            "hoian-fees-2026"
          ],
          "checkedAt": "2026-10-20",
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Nguồn vé xác nhận quyền chọn Chùa Cầu nhưng chưa có lịch mở riêng; vui lòng kiểm tra tại quầy trước khi đến."
          ]
        }
      },
      "notes": [
        "Giá có nguồn tham khảo tại ngày kiểm tra; kiểm tra thông báo và quyền lợi khi mua vé."
      ]
    },
    {
      "placeId": "hoi-an/tan-ky",
      "visitScopeLabel": "Nhà cổ Tấn Ký",
      "price": {
        "options": [
          {
            "id": "heritage-80",
            "conditions": [
              "Mức tiền là cho gói, không phải vé lẻ riêng của địa điểm này. Kiểm tra còn ô phù hợp cho điểm muốn vào."
            ],
            "included": [],
            "currency": "VND",
            "label": "Gói vé phố cổ 80.000đ",
            "audience": "Chọn gói theo quyền lợi công bố",
            "amountVnd": 80000,
            "unit": "người/gói",
            "excluded": [],
            "packageId": "hoian-heritage-80"
          },
          {
            "id": "heritage-120",
            "conditions": [
              "Mức tiền là cho gói, không phải vé lẻ riêng của địa điểm này. Kiểm tra còn ô phù hợp cho điểm muốn vào."
            ],
            "included": [],
            "currency": "VND",
            "label": "Gói vé phố cổ 120.000đ",
            "audience": "Chọn gói theo quyền lợi công bố",
            "amountVnd": 120000,
            "unit": "người/gói",
            "excluded": [],
            "packageId": "hoian-heritage-120"
          }
        ],
        "status": "bundled",
        "evidence": {
          "conditions": [
            "Giá/quyền lợi dùng thông tin 16/03/2026; danh mục cũ chỉ đối chiếu tên điểm, không dùng giá theo quốc tịch hay lịch cũ."
          ],
          "unresolvedIssues": [],
          "reviewState": "reviewed",
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hoian-fees-2026",
            "hoian-ticket-sites"
          ]
        }
      },
      "hours": {
        "rules": [
          {
            "startMinutes": 480,
            "label": "Buổi sáng — thứ Hai đến Chủ nhật",
            "endDayOffset": 0,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "endMinutes": 690
          },
          {
            "startMinutes": 810,
            "label": "Buổi chiều — thứ Hai đến Chủ nhật",
            "endDayOffset": 0,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "endMinutes": 1065
          }
        ],
        "status": "scheduled",
        "notes": [
          "Có nghỉ giữa ngày theo hồ sơ giới thiệu; hạn chế tiếng ồn, không chạm hiện vật. Kiểm tra lịch đặc biệt tại nơi tham quan."
        ],
        "evidence": {
          "conditions": [
            "Cổng Hội An dẫn bài Traveloka, chưa ghi ngày công bố/hiệu lực. Đây là giờ tham khảo có nguồn; xác nhận lại với điểm trước khi đến."
          ],
          "unresolvedIssues": [],
          "reviewState": "reviewed",
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hoian-tanky-hours"
          ]
        }
      },
      "notes": [
        "Giá có nguồn tham khảo tại ngày kiểm tra; kiểm tra thông báo và quyền lợi khi mua vé."
      ]
    },
    {
      "placeId": "hoi-an/history-museum",
      "visitScopeLabel": "Bảo tàng Lịch sử – Văn hóa Hội An — 10B Trần Hưng Đạo",
      "price": {
        "options": [
          {
            "id": "heritage-120",
            "conditions": [
              "Mức tiền là cho gói, không phải vé lẻ riêng của địa điểm này. Kiểm tra còn ô phù hợp cho điểm muốn vào."
            ],
            "included": [],
            "currency": "VND",
            "label": "Gói vé phố cổ 120.000đ",
            "audience": "Chọn gói theo quyền lợi công bố",
            "amountVnd": 120000,
            "unit": "người/gói",
            "excluded": [],
            "packageId": "hoian-heritage-120"
          }
        ],
        "status": "bundled",
        "evidence": {
          "conditions": [
            "Giá/quyền lợi dùng thông tin 16/03/2026; danh mục cũ chỉ đối chiếu tên điểm, không dùng giá theo quốc tịch hay lịch cũ."
          ],
          "unresolvedIssues": [],
          "reviewState": "reviewed",
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hoian-fees-2026",
            "hoian-ticket-sites"
          ]
        }
      },
      "hours": {
        "rules": [
          {
            "startMinutes": 420,
            "label": "Hằng ngày theo hồ sơ giới thiệu",
            "endDayOffset": 0,
            "weekdays": [
              1,
              2,
              3,
              4,
              5,
              6,
              7
            ],
            "endMinutes": 1020
          }
        ],
        "status": "scheduled",
        "notes": [
          "Giờ theo mục giới thiệu trên cổng Hội An; chưa thấy ngày công bố hoặc mốc hiệu lực trong bài. Kiểm tra lịch đặc biệt trước khi đi."
        ],
        "evidence": {
          "conditions": [
            "Cổng Hội An đăng mục tổng hợp, không phải thông báo vận hành theo ngày; không dùng lịch phố đi bộ thay cho giờ bảo tàng."
          ],
          "unresolvedIssues": [],
          "reviewState": "reviewed",
          "checkedAt": "2026-10-20",
          "sourceIds": [
            "hoian-museum-hours"
          ]
        }
      },
      "notes": [
        "Giá có nguồn tham khảo tại ngày kiểm tra; kiểm tra thông báo và quyền lợi khi mua vé."
      ]
    },
    {
      "placeId": "hoi-an/an-bang",
      "visitScopeLabel": "Biển An Bàng",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "hoi-an/cua-dai",
      "visitScopeLabel": "Biển Cửa Đại",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "nha-trang/city-beach",
      "visitScopeLabel": "Bãi biển Nha Trang",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "nha-trang/hon-mun",
      "visitScopeLabel": "Hòn Mun",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "nha-trang/monkey-island",
      "visitScopeLabel": "Đảo Khỉ",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "nha-trang/long-son",
      "visitScopeLabel": "Chùa Long Sơn",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "nha-trang/po-nagar",
      "visitScopeLabel": "Tháp Bà Po Nagar",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "nha-trang/bao-dai",
      "visitScopeLabel": "Biệt thự Bảo Đại",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "da-lat/xuan-huong",
      "visitScopeLabel": "Hồ Xuân Hương",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "da-lat/central-market",
      "visitScopeLabel": "Chợ Đà Lạt",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "da-lat/railway-station",
      "visitScopeLabel": "Ga Đà Lạt",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "da-lat/lang-biang",
      "visitScopeLabel": "Lang Biang",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "da-lat/bidoup",
      "visitScopeLabel": "Vườn quốc gia Bidoup – Núi Bà",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "da-lat/linh-phuoc",
      "visitScopeLabel": "Chùa Linh Phước",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ho-chi-minh/notre-dame",
      "visitScopeLabel": "Nhà thờ Đức Bà Sài Gòn",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ho-chi-minh/post-office",
      "visitScopeLabel": "Bưu điện Trung tâm Sài Gòn",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ho-chi-minh/opera",
      "visitScopeLabel": "Nhà hát Thành phố",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ho-chi-minh/ben-thanh",
      "visitScopeLabel": "Chợ Bến Thành",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ho-chi-minh/jade-emperor",
      "visitScopeLabel": "Chùa Ngọc Hoàng",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "ho-chi-minh/binh-tay",
      "visitScopeLabel": "Chợ Bình Tây",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "phu-quoc/sao",
      "visitScopeLabel": "Bãi Sao",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "phu-quoc/hon-thom",
      "visitScopeLabel": "Hòn Thơm",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "phu-quoc/national-park",
      "visitScopeLabel": "Vườn quốc gia Phú Quốc",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "phu-quoc/long-beach",
      "visitScopeLabel": "Bãi Trường",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "phu-quoc/ganh-dau",
      "visitScopeLabel": "Mũi Gành Dầu",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "phu-quoc/dinh-cau",
      "visitScopeLabel": "Dinh Cậu",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "can-tho/cai-rang",
      "visitScopeLabel": "Chợ nổi Cái Răng",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "can-tho/ninh-kieu",
      "visitScopeLabel": "Bến Ninh Kiều",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "can-tho/ong-pagoda",
      "visitScopeLabel": "Chùa Ông",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "can-tho/binh-thuy",
      "visitScopeLabel": "Nhà cổ Bình Thủy",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "can-tho/con-son",
      "visitScopeLabel": "Cồn Sơn",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    },
    {
      "placeId": "can-tho/bang-lang",
      "visitScopeLabel": "Vườn cò Bằng Lăng",
      "price": {
        "status": "unverified",
        "options": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giá và điều kiện áp dụng."
          ]
        }
      },
      "hours": {
        "status": "unverified",
        "rules": [],
        "notes": [],
        "evidence": {
          "sourceIds": [],
          "checkedAt": null,
          "reviewState": "unverified",
          "conditions": [],
          "unresolvedIssues": [
            "Chưa đối chiếu đủ nguồn giờ tham quan."
          ]
        }
      },
      "notes": []
    }
  ]
}
$visit_seed$::jsonb || $inventory_seed${"inventory":{"schemaVersion":1,"destinations":[{"imageUrl":null,"description":"","isActive":true,"slug":"ha-noi","name":"Hà Nội","region":"","id":"ha-noi"},{"imageUrl":null,"description":"","isActive":true,"slug":"ha-long","name":"Hạ Long","region":"","id":"ha-long"},{"imageUrl":null,"description":"","isActive":true,"slug":"sa-pa","name":"Sa Pa","region":"","id":"sa-pa"},{"imageUrl":null,"description":"","isActive":true,"slug":"ninh-binh","name":"Ninh Bình","region":"","id":"ninh-binh"},{"imageUrl":null,"description":"","isActive":true,"slug":"hue","name":"Huế","region":"","id":"hue"},{"imageUrl":null,"description":"","isActive":true,"slug":"da-nang","name":"Đà Nẵng","region":"","id":"da-nang"},{"imageUrl":null,"description":"","isActive":true,"slug":"hoi-an","name":"Hội An","region":"","id":"hoi-an"},{"imageUrl":null,"description":"","isActive":true,"slug":"nha-trang","name":"Nha Trang","region":"","id":"nha-trang"},{"imageUrl":null,"description":"","isActive":true,"slug":"da-lat","name":"Đà Lạt","region":"","id":"da-lat"},{"imageUrl":null,"description":"","isActive":true,"slug":"ho-chi-minh","name":"TP. Hồ Chí Minh","region":"","id":"ho-chi-minh"},{"imageUrl":null,"description":"","isActive":true,"slug":"phu-quoc","name":"Phú Quốc","region":"","id":"phu-quoc"},{"imageUrl":null,"description":"","isActive":true,"slug":"can-tho","name":"Cần Thơ","region":"","id":"can-tho"}],"places":[{"destinationId":"ha-noi","isActive":true,"slug":"hoan-kiem","imageUrl":null,"name":"Hồ Hoàn Kiếm","description":"","id":"ha-noi/hoan-kiem","latitude":null,"longitude":null},{"destinationId":"ha-noi","isActive":true,"slug":"van-mieu","imageUrl":null,"name":"Văn Miếu – Quốc Tử Giám","description":"","id":"ha-noi/van-mieu","latitude":null,"longitude":null},{"destinationId":"ha-noi","isActive":true,"slug":"old-quarter","imageUrl":null,"name":"Phố cổ Hà Nội","description":"","id":"ha-noi/old-quarter","latitude":null,"longitude":null},{"destinationId":"ha-noi","isActive":true,"slug":"opera","imageUrl":null,"name":"Nhà hát Lớn Hà Nội","description":"","id":"ha-noi/opera","latitude":null,"longitude":null},{"destinationId":"ha-noi","isActive":true,"slug":"one-pillar","imageUrl":null,"name":"Chùa Một Cột","description":"","id":"ha-noi/one-pillar","latitude":null,"longitude":null},{"destinationId":"ha-noi","isActive":true,"slug":"st-joseph","imageUrl":null,"name":"Nhà thờ Lớn Hà Nội","description":"","id":"ha-noi/st-joseph","latitude":null,"longitude":null},{"destinationId":"ha-long","isActive":true,"slug":"bay","imageUrl":null,"name":"Vịnh Hạ Long","description":"","id":"ha-long/bay","latitude":null,"longitude":null},{"destinationId":"ha-long","isActive":true,"slug":"sung-sot","imageUrl":null,"name":"Hang Sửng Sốt","description":"","id":"ha-long/sung-sot","latitude":null,"longitude":null},{"destinationId":"ha-long","isActive":true,"slug":"me-cung","imageUrl":null,"name":"Hang Mê Cung","description":"","id":"ha-long/me-cung","latitude":null,"longitude":null},{"destinationId":"ha-long","isActive":true,"slug":"thien-cung","imageUrl":null,"name":"Động Thiên Cung","description":"","id":"ha-long/thien-cung","latitude":null,"longitude":null},{"destinationId":"ha-long","isActive":true,"slug":"ga-choi","imageUrl":null,"name":"Hòn Gà Chọi","description":"","id":"ha-long/ga-choi","latitude":null,"longitude":null},{"destinationId":"ha-long","isActive":true,"slug":"tuan-chau","imageUrl":null,"name":"Tuần Châu","description":"","id":"ha-long/tuan-chau","latitude":null,"longitude":null},{"destinationId":"sa-pa","isActive":true,"slug":"fansipan","imageUrl":null,"name":"Fansipan","description":"","id":"sa-pa/fansipan","latitude":null,"longitude":null},{"destinationId":"sa-pa","isActive":true,"slug":"cat-cat","imageUrl":null,"name":"Bản Cát Cát","description":"","id":"sa-pa/cat-cat","latitude":null,"longitude":null},{"destinationId":"sa-pa","isActive":true,"slug":"ta-phin","imageUrl":null,"name":"Bản Tả Phìn","description":"","id":"sa-pa/ta-phin","latitude":null,"longitude":null},{"destinationId":"sa-pa","isActive":true,"slug":"bac-ha","imageUrl":null,"name":"Chợ Bắc Hà","description":"","id":"sa-pa/bac-ha","latitude":null,"longitude":null},{"destinationId":"sa-pa","isActive":true,"slug":"muong-hum","imageUrl":null,"name":"Chợ Mường Hum","description":"","id":"sa-pa/muong-hum","latitude":null,"longitude":null},{"destinationId":"sa-pa","isActive":true,"slug":"sapa-napro","imageUrl":null,"name":"SAPANAPRO, Tả Phìn","description":"","id":"sa-pa/sapa-napro","latitude":null,"longitude":null},{"destinationId":"ninh-binh","isActive":true,"slug":"hang-mua","imageUrl":null,"name":"Hang Múa","description":"","id":"ninh-binh/hang-mua","latitude":null,"longitude":null},{"destinationId":"ninh-binh","isActive":true,"slug":"tam-coc","imageUrl":null,"name":"Tam Cốc","description":"","id":"ninh-binh/tam-coc","latitude":null,"longitude":null},{"destinationId":"ninh-binh","isActive":true,"slug":"trang-an","imageUrl":null,"name":"Tràng An","description":"","id":"ninh-binh/trang-an","latitude":null,"longitude":null},{"destinationId":"ninh-binh","isActive":true,"slug":"hoa-lu","imageUrl":null,"name":"Cố đô Hoa Lư","description":"","id":"ninh-binh/hoa-lu","latitude":null,"longitude":null},{"destinationId":"ninh-binh","isActive":true,"slug":"van-long","imageUrl":null,"name":"Đầm Vân Long","description":"","id":"ninh-binh/van-long","latitude":null,"longitude":null},{"destinationId":"ninh-binh","isActive":true,"slug":"bai-dinh","imageUrl":null,"name":"Chùa Bái Đính","description":"","id":"ninh-binh/bai-dinh","latitude":null,"longitude":null},{"destinationId":"hue","isActive":true,"slug":"citadel","imageUrl":null,"name":"Kinh thành Huế","description":"","id":"hue/citadel","latitude":null,"longitude":null},{"destinationId":"hue","isActive":true,"slug":"tu-duc","imageUrl":null,"name":"Lăng Tự Đức","description":"","id":"hue/tu-duc","latitude":null,"longitude":null},{"destinationId":"hue","isActive":true,"slug":"minh-mang","imageUrl":null,"name":"Lăng Minh Mạng","description":"","id":"hue/minh-mang","latitude":null,"longitude":null},{"destinationId":"hue","isActive":true,"slug":"khai-dinh","imageUrl":null,"name":"Lăng Khải Định","description":"","id":"hue/khai-dinh","latitude":null,"longitude":null},{"destinationId":"hue","isActive":true,"slug":"dong-ba","imageUrl":null,"name":"Chợ Đông Ba","description":"","id":"hue/dong-ba","latitude":null,"longitude":null},{"destinationId":"hue","isActive":true,"slug":"thien-mu","imageUrl":null,"name":"Chùa Thiên Mụ","description":"","id":"hue/thien-mu","latitude":null,"longitude":null},{"destinationId":"da-nang","isActive":true,"slug":"my-khe","imageUrl":null,"name":"Biển Mỹ Khê","description":"","id":"da-nang/my-khe","latitude":null,"longitude":null},{"destinationId":"da-nang","isActive":true,"slug":"marble","imageUrl":null,"name":"Ngũ Hành Sơn","description":"","id":"da-nang/marble","latitude":null,"longitude":null},{"destinationId":"da-nang","isActive":true,"slug":"son-tra","imageUrl":null,"name":"Bán đảo Sơn Trà","description":"","id":"da-nang/son-tra","latitude":null,"longitude":null},{"destinationId":"da-nang","isActive":true,"slug":"lady-buddha","imageUrl":null,"name":"Tượng Quan Thế Âm — chùa Linh Ứng Bãi Bụt, Sơn Trà","description":"","id":"da-nang/lady-buddha","latitude":null,"longitude":null},{"destinationId":"da-nang","isActive":true,"slug":"hai-van","imageUrl":null,"name":"Đèo Hải Vân","description":"","id":"da-nang/hai-van","latitude":null,"longitude":null},{"destinationId":"da-nang","isActive":true,"slug":"han-market","imageUrl":null,"name":"Chợ Hàn","description":"","id":"da-nang/han-market","latitude":null,"longitude":null},{"destinationId":"hoi-an","isActive":true,"slug":"ancient-town","imageUrl":null,"name":"Phố cổ Hội An","description":"","id":"hoi-an/ancient-town","latitude":null,"longitude":null},{"destinationId":"hoi-an","isActive":true,"slug":"japanese-bridge","imageUrl":null,"name":"Chùa Cầu","description":"","id":"hoi-an/japanese-bridge","latitude":null,"longitude":null},{"destinationId":"hoi-an","isActive":true,"slug":"tan-ky","imageUrl":null,"name":"Nhà cổ Tấn Ký","description":"","id":"hoi-an/tan-ky","latitude":null,"longitude":null},{"destinationId":"hoi-an","isActive":true,"slug":"history-museum","imageUrl":null,"name":"Bảo tàng Lịch sử – Văn hóa Hội An","description":"","id":"hoi-an/history-museum","latitude":null,"longitude":null},{"destinationId":"hoi-an","isActive":true,"slug":"an-bang","imageUrl":null,"name":"Biển An Bàng","description":"","id":"hoi-an/an-bang","latitude":null,"longitude":null},{"destinationId":"hoi-an","isActive":true,"slug":"cua-dai","imageUrl":null,"name":"Biển Cửa Đại","description":"","id":"hoi-an/cua-dai","latitude":null,"longitude":null},{"destinationId":"nha-trang","isActive":true,"slug":"city-beach","imageUrl":null,"name":"Bãi biển Nha Trang","description":"","id":"nha-trang/city-beach","latitude":null,"longitude":null},{"destinationId":"nha-trang","isActive":true,"slug":"hon-mun","imageUrl":null,"name":"Hòn Mun","description":"","id":"nha-trang/hon-mun","latitude":null,"longitude":null},{"destinationId":"nha-trang","isActive":true,"slug":"monkey-island","imageUrl":null,"name":"Đảo Khỉ","description":"","id":"nha-trang/monkey-island","latitude":null,"longitude":null},{"destinationId":"nha-trang","isActive":true,"slug":"long-son","imageUrl":null,"name":"Chùa Long Sơn","description":"","id":"nha-trang/long-son","latitude":null,"longitude":null},{"destinationId":"nha-trang","isActive":true,"slug":"po-nagar","imageUrl":null,"name":"Tháp Bà Po Nagar","description":"","id":"nha-trang/po-nagar","latitude":null,"longitude":null},{"destinationId":"nha-trang","isActive":true,"slug":"bao-dai","imageUrl":null,"name":"Biệt thự Bảo Đại","description":"","id":"nha-trang/bao-dai","latitude":null,"longitude":null},{"destinationId":"da-lat","isActive":true,"slug":"xuan-huong","imageUrl":null,"name":"Hồ Xuân Hương","description":"","id":"da-lat/xuan-huong","latitude":null,"longitude":null},{"destinationId":"da-lat","isActive":true,"slug":"central-market","imageUrl":null,"name":"Chợ Đà Lạt","description":"","id":"da-lat/central-market","latitude":null,"longitude":null},{"destinationId":"da-lat","isActive":true,"slug":"railway-station","imageUrl":null,"name":"Ga Đà Lạt","description":"","id":"da-lat/railway-station","latitude":null,"longitude":null},{"destinationId":"da-lat","isActive":true,"slug":"lang-biang","imageUrl":null,"name":"Lang Biang","description":"","id":"da-lat/lang-biang","latitude":null,"longitude":null},{"destinationId":"da-lat","isActive":true,"slug":"bidoup","imageUrl":null,"name":"Vườn quốc gia Bidoup – Núi Bà","description":"","id":"da-lat/bidoup","latitude":null,"longitude":null},{"destinationId":"da-lat","isActive":true,"slug":"linh-phuoc","imageUrl":null,"name":"Chùa Linh Phước","description":"","id":"da-lat/linh-phuoc","latitude":null,"longitude":null},{"destinationId":"ho-chi-minh","isActive":true,"slug":"notre-dame","imageUrl":null,"name":"Nhà thờ Đức Bà Sài Gòn","description":"","id":"ho-chi-minh/notre-dame","latitude":null,"longitude":null},{"destinationId":"ho-chi-minh","isActive":true,"slug":"post-office","imageUrl":null,"name":"Bưu điện Trung tâm Sài Gòn","description":"","id":"ho-chi-minh/post-office","latitude":null,"longitude":null},{"destinationId":"ho-chi-minh","isActive":true,"slug":"opera","imageUrl":null,"name":"Nhà hát Thành phố","description":"","id":"ho-chi-minh/opera","latitude":null,"longitude":null},{"destinationId":"ho-chi-minh","isActive":true,"slug":"ben-thanh","imageUrl":null,"name":"Chợ Bến Thành","description":"","id":"ho-chi-minh/ben-thanh","latitude":null,"longitude":null},{"destinationId":"ho-chi-minh","isActive":true,"slug":"jade-emperor","imageUrl":null,"name":"Chùa Ngọc Hoàng","description":"","id":"ho-chi-minh/jade-emperor","latitude":null,"longitude":null},{"destinationId":"ho-chi-minh","isActive":true,"slug":"binh-tay","imageUrl":null,"name":"Chợ Bình Tây","description":"","id":"ho-chi-minh/binh-tay","latitude":null,"longitude":null},{"destinationId":"phu-quoc","isActive":true,"slug":"sao","imageUrl":null,"name":"Bãi Sao","description":"","id":"phu-quoc/sao","latitude":null,"longitude":null},{"destinationId":"phu-quoc","isActive":true,"slug":"hon-thom","imageUrl":null,"name":"Hòn Thơm","description":"","id":"phu-quoc/hon-thom","latitude":null,"longitude":null},{"destinationId":"phu-quoc","isActive":true,"slug":"national-park","imageUrl":null,"name":"Vườn quốc gia Phú Quốc","description":"","id":"phu-quoc/national-park","latitude":null,"longitude":null},{"destinationId":"phu-quoc","isActive":true,"slug":"long-beach","imageUrl":null,"name":"Bãi Trường","description":"","id":"phu-quoc/long-beach","latitude":null,"longitude":null},{"destinationId":"phu-quoc","isActive":true,"slug":"ganh-dau","imageUrl":null,"name":"Mũi Gành Dầu","description":"","id":"phu-quoc/ganh-dau","latitude":null,"longitude":null},{"destinationId":"phu-quoc","isActive":true,"slug":"dinh-cau","imageUrl":null,"name":"Dinh Cậu","description":"","id":"phu-quoc/dinh-cau","latitude":null,"longitude":null},{"destinationId":"can-tho","isActive":true,"slug":"cai-rang","imageUrl":null,"name":"Chợ nổi Cái Răng","description":"","id":"can-tho/cai-rang","latitude":null,"longitude":null},{"destinationId":"can-tho","isActive":true,"slug":"ninh-kieu","imageUrl":null,"name":"Bến Ninh Kiều","description":"","id":"can-tho/ninh-kieu","latitude":null,"longitude":null},{"destinationId":"can-tho","isActive":true,"slug":"ong-pagoda","imageUrl":null,"name":"Chùa Ông","description":"","id":"can-tho/ong-pagoda","latitude":null,"longitude":null},{"destinationId":"can-tho","isActive":true,"slug":"binh-thuy","imageUrl":null,"name":"Nhà cổ Bình Thủy","description":"","id":"can-tho/binh-thuy","latitude":null,"longitude":null},{"destinationId":"can-tho","isActive":true,"slug":"con-son","imageUrl":null,"name":"Cồn Sơn","description":"","id":"can-tho/con-son","latitude":null,"longitude":null},{"destinationId":"can-tho","isActive":true,"slug":"bang-lang","imageUrl":null,"name":"Vườn cò Bằng Lăng","description":"","id":"can-tho/bang-lang","latitude":null,"longitude":null}]}}$inventory_seed$::jsonb);
INSERT INTO private_discovery_admin.versions(revision,reason,payload,payload_hash)
 SELECT 1,'Nhập dữ liệu hiện có; chưa xuất bản',payload,md5(payload::text)
 FROM private_discovery_admin.draft;

CREATE FUNCTION private_discovery_admin.valid_date(value text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $$ BEGIN
 IF value IS NULL THEN RETURN true; END IF;
 IF value !~ '^\d{4}-\d{2}-\d{2}$' THEN RETURN false; END IF;
 RETURN to_char(value::date,'YYYY-MM-DD')=value;
 EXCEPTION WHEN datetime_field_overflow OR invalid_datetime_format THEN RETURN false;
END $$;
REVOKE ALL ON FUNCTION private_discovery_admin.valid_date(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION private_discovery_admin.sync_inventory(data jsonb,previous jsonb) RETURNS void
LANGUAGE plpgsql SET search_path='' AS $sync$
DECLARE item jsonb; f jsonb; e jsonb; rule jsonb; option jsonb; ref text; key text;
 ds jsonb:=data->'inventory'->'destinations'; ps jsonb:=data->'inventory'->'places';
BEGIN
 IF jsonb_typeof(ds) IS DISTINCT FROM 'array' OR jsonb_typeof(ps) IS DISTINCT FROM 'array'
 OR data->'inventory'->'schemaVersion' IS DISTINCT FROM '1'::jsonb
 OR jsonb_typeof(data->'places') IS DISTINCT FROM 'array'
 OR jsonb_typeof(data->'sources') IS DISTINCT FROM 'array'
 OR jsonb_typeof(data->'packages') IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_shape'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(ds||ps) x WHERE
   jsonb_typeof(x) IS DISTINCT FROM 'object' OR jsonb_typeof(x->'id') IS DISTINCT FROM 'string'
   OR jsonb_typeof(x->'name') IS DISTINCT FROM 'string' OR jsonb_typeof(x->'slug') IS DISTINCT FROM 'string'
   OR jsonb_typeof(x->'description') IS DISTINCT FROM 'string' OR jsonb_typeof(x->'isActive') IS DISTINCT FROM 'boolean')
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(ds) x WHERE jsonb_typeof(x->'region') IS DISTINCT FROM 'string')
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(ps) x WHERE jsonb_typeof(x->'destinationId') IS DISTINCT FROM 'string'
   OR jsonb_typeof(x->'latitude') NOT IN ('number','null') OR NOT(x?'latitude')
   OR jsonb_typeof(x->'longitude') NOT IN ('number','null') OR NOT(x?'longitude')) THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_record_shape'; END IF;
 IF (SELECT count(*)<>count(DISTINCT value->>'id') FROM jsonb_array_elements(ds))
 OR (SELECT count(*)<>count(DISTINCT value->>'id') FROM jsonb_array_elements(ps))
 OR (SELECT count(*)<>count(DISTINCT value->>'slug') FROM jsonb_array_elements(ds))
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(ps) GROUP BY value->>'destinationId',value->>'slug' HAVING count(*)>1) THEN
  RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='catalogue_duplicate_id_or_slug'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(ps) p WHERE NOT EXISTS
  (SELECT 1 FROM jsonb_array_elements(ds) d WHERE d->>'id'=p->>'destinationId')) THEN
  RAISE EXCEPTION USING ERRCODE='23503',MESSAGE='catalogue_destination_missing'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(ps) p JOIN jsonb_array_elements(ds) d ON d->>'id'=p->>'destinationId'
   WHERE p->>'isActive'='true' AND d->>'isActive'='false') THEN
  RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='catalogue_active_child_of_hidden_destination'; END IF;
 IF previous IS NOT NULL AND (
   EXISTS(SELECT 1 FROM jsonb_array_elements(previous->'inventory'->'destinations') old
     WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(ds) n WHERE n->>'id'=old->>'id'))
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(previous->'inventory'->'places') old
     WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(ps) n WHERE n->>'id'=old->>'id'))) THEN
  RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='catalogue_ids_immutable_archive_instead'; END IF;
 IF (SELECT jsonb_agg(value->>'id' ORDER BY value->>'id') FROM jsonb_array_elements(ps)) IS DISTINCT FROM
    (SELECT jsonb_agg(value->>'placeId' ORDER BY value->>'placeId') FROM jsonb_array_elements(data->'places')) THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_visit_details_mismatch'; END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(data->'sources') x GROUP BY x->>'id' HAVING count(*)>1)
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(data->'packages') x GROUP BY x->>'id' HAVING count(*)>1) THEN
  RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='catalogue_duplicate_source_or_package'; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements((data->'sources')||(data->'packages')) LOOP
  IF jsonb_typeof(item) IS DISTINCT FROM 'object' OR nullif(btrim(item->>'id'),'') IS NULL THEN
   RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_shared_record'; END IF;
  FOREACH key IN ARRAY ARRAY['publishedAt','effectiveFrom','effectiveTo'] LOOP
   IF NOT private_discovery_admin.valid_date(item->>key) THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_invalid_date'; END IF;
  END LOOP;
  IF item->>'effectiveFrom'>item->>'effectiveTo' THEN
   RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_date_order'; END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(data->'places') LOOP
  FOREACH key IN ARRAY ARRAY['price','hours'] LOOP
   f:=item->key; e:=f->'evidence';
   IF jsonb_typeof(f) IS DISTINCT FROM 'object' OR jsonb_typeof(e) IS DISTINCT FROM 'object'
    OR jsonb_typeof(e->'sourceIds') IS DISTINCT FROM 'array'
    OR coalesce(e->>'reviewState','') NOT IN ('unverified','reviewed')
    OR NOT private_discovery_admin.valid_date(e->>'checkedAt')
    OR (e->>'checkedAt')::date>(now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_evidence'; END IF;
   IF (key='price' AND coalesce(f->>'status','') NOT IN ('priced','free','bundled','variable','unverified'))
    OR (key='hours' AND coalesce(f->>'status','') NOT IN ('scheduled','seasonal','event_based','no_fixed_hours','temporarily_closed','unverified')) THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_unknown_status'; END IF;
   FOR ref IN SELECT jsonb_array_elements_text(e->'sourceIds') LOOP
    IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(data->'sources') s WHERE s->>'id'=ref) THEN
     RAISE EXCEPTION USING ERRCODE='23503',MESSAGE='catalogue_source_missing'; END IF;
   END LOOP;
   IF e->>'reviewState'='reviewed' AND (jsonb_array_length(e->'sourceIds')=0
    OR e->>'checkedAt' IS NULL OR f->>'status'='unverified'
    OR jsonb_typeof(e->'unresolvedIssues') IS DISTINCT FROM 'array'
    OR jsonb_array_length(e->'unresolvedIssues')<>0
    OR EXISTS(SELECT 1 FROM jsonb_array_elements(data->'sources') s
     WHERE e->'sourceIds' ? (s->>'id') AND (nullif(btrim(s->>'title'),'') IS NULL
      OR nullif(btrim(s->>'publisher'),'') IS NULL OR coalesce(s->>'url','') !~ '^https://[^/@[:space:]]+(/[^[:space:]]*)?$'))) THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_review_requires_evidence'; END IF;
  END LOOP;
  IF jsonb_typeof(item->'price'->'options') IS DISTINCT FROM 'array'
   OR jsonb_typeof(item->'hours'->'rules') IS DISTINCT FROM 'array' THEN
   RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_operational_shape'; END IF;
  FOR option IN SELECT value FROM jsonb_array_elements(item->'price'->'options') LOOP
   IF jsonb_typeof(option) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='catalogue_price_option_shape'; END IF;
   IF option->'amountVnd'<>'null'::jsonb AND (jsonb_typeof(option->'amountVnd') IS DISTINCT FROM 'number'
    OR (option->>'amountVnd')::numeric<0 OR (option->>'amountVnd')::numeric>9007199254740991
    OR trunc((option->>'amountVnd')::numeric)<>(option->>'amountVnd')::numeric) THEN
    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='catalogue_invalid_price'; END IF;
   IF option->>'packageId' IS NOT NULL AND NOT EXISTS
    (SELECT 1 FROM jsonb_array_elements(data->'packages') p WHERE p->>'id'=option->>'packageId') THEN
    RAISE EXCEPTION USING ERRCODE='23503',MESSAGE='catalogue_package_missing'; END IF;
  END LOOP;
  FOR rule IN SELECT value FROM jsonb_array_elements(item->'hours'->'rules') LOOP
   IF jsonb_typeof(rule->'weekdays') IS DISTINCT FROM 'array' OR jsonb_array_length(rule->'weekdays')=0
    OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(rule->'weekdays') d WHERE d::int NOT BETWEEN 1 AND 7)
    OR (SELECT count(*)<>count(DISTINCT value) FROM jsonb_array_elements(rule->'weekdays'))
    OR (rule->>'endDayOffset')::int NOT BETWEEN 0 AND 1 THEN
    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='catalogue_invalid_weekdays'; END IF;
   FOREACH key IN ARRAY ARRAY['startMinutes','endMinutes','admissionCutoffMinutes','lastReturnMinutes'] LOOP
    IF rule->>key IS NOT NULL AND ((rule->>key)::numeric NOT BETWEEN 0 AND 1439
      OR trunc((rule->>key)::numeric)<>(rule->>key)::numeric) THEN
     RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='catalogue_invalid_time'; END IF;
   END LOOP;
   IF rule->>'startMinutes' IS NOT NULL AND rule->>'endMinutes' IS NOT NULL
    AND ((rule->>'endMinutes')::int+coalesce((rule->>'endDayOffset')::int,0)*1440-(rule->>'startMinutes')::int NOT BETWEEN 1 AND 1440) THEN
    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='catalogue_time_order'; END IF;
   IF NOT private_discovery_admin.valid_date(rule->>'effectiveFrom')
    OR NOT private_discovery_admin.valid_date(rule->>'effectiveTo') OR rule->>'effectiveFrom'>rule->>'effectiveTo'
    OR ((rule->>'seasonStart' IS NULL)<>(rule->>'seasonEnd' IS NULL))
    OR (rule->>'seasonStart' IS NOT NULL AND (NOT private_discovery_admin.valid_date('2000-'||(rule->>'seasonStart'))
      OR NOT private_discovery_admin.valid_date('2000-'||(rule->>'seasonEnd')))) THEN
    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='catalogue_invalid_season_or_dates'; END IF;
  END LOOP;
 END LOOP;
 INSERT INTO private_discovery_admin.destinations(id,name,slug,description,image_url,region,is_active)
  SELECT id,name,slug,description,"imageUrl",region,"isActive" FROM jsonb_to_recordset(ds)
   AS r(id text,name text,slug text,description text,"imageUrl" text,region text,"isActive" boolean)
  ON CONFLICT(id) DO UPDATE SET name=excluded.name,slug=excluded.slug,description=excluded.description,
   image_url=excluded.image_url,region=excluded.region,is_active=excluded.is_active;
 INSERT INTO private_discovery_admin.places(id,destination_id,name,slug,description,image_url,latitude,longitude,is_active)
  SELECT id,"destinationId",name,slug,description,"imageUrl",latitude,longitude,"isActive" FROM jsonb_to_recordset(ps)
   AS r(id text,"destinationId" text,name text,slug text,description text,"imageUrl" text,latitude double precision,longitude double precision,"isActive" boolean)
  ON CONFLICT(id) DO UPDATE SET destination_id=excluded.destination_id,name=excluded.name,slug=excluded.slug,
   description=excluded.description,image_url=excluded.image_url,latitude=excluded.latitude,longitude=excluded.longitude,is_active=excluded.is_active;
END $sync$;
REVOKE ALL ON FUNCTION private_discovery_admin.sync_inventory(jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
SELECT private_discovery_admin.sync_inventory(payload,NULL) FROM private_discovery_admin.draft;

CREATE FUNCTION private_discovery_admin.require_actor() RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $actor$
DECLARE subject uuid := auth.uid(); session_uuid uuid; actor uuid;
BEGIN
 BEGIN session_uuid := nullif(auth.jwt()->>'session_id','')::uuid;
 EXCEPTION WHEN invalid_text_representation THEN
   RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='admin_session_required';
 END;
 IF subject IS NULL OR session_uuid IS NULL THEN
   RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='admin_session_required';
 END IF;
 SELECT p.id INTO actor FROM public.profiles p
 JOIN auth.users u ON u.id=p.id
 JOIN auth.sessions s ON s.user_id=p.id AND s.id=session_uuid
 WHERE p.id=subject AND p.role='admin' AND NOT coalesce(u.is_anonymous,false)
   AND u.deleted_at IS NULL AND (u.banned_until IS NULL OR u.banned_until<=now())
   AND (s.not_after IS NULL OR s.not_after>now())
 FOR SHARE OF p,u,s;
 IF actor IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='admin_session_required'; END IF;
 RETURN actor;
END $actor$;
REVOKE ALL ON FUNCTION private_discovery_admin.require_actor() FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION private_discovery_admin.endpoint(
 p_action text,p_payload jsonb,p_expected_revision bigint,p_reason text,p_request_id uuid,p_revision bigint)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $endpoint$
DECLARE actor uuid; current_draft private_discovery_admin.draft;
 prior private_discovery_admin.versions; snapshot private_discovery_admin.versions;
 base_payload jsonb; history jsonb;
BEGIN
 actor:=private_discovery_admin.require_actor();
 IF p_action IS NULL OR p_action NOT IN ('read','save','version') THEN
   RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='admin_action_invalid';
 END IF;
 IF p_action='save' THEN
   IF p_request_id IS NULL OR p_expected_revision IS NULL OR p_expected_revision<1
     OR p_reason IS NULL OR char_length(btrim(p_reason)) NOT BETWEEN 1 AND 500 THEN
     RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='draft_save_parameters';
   END IF;
   IF p_payload IS NULL OR jsonb_typeof(p_payload)<>'object' OR octet_length(p_payload::text)>2097152 THEN
     RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='draft_shape';
   END IF;
   SELECT * INTO current_draft FROM private_discovery_admin.draft WHERE singleton FOR UPDATE;
   SELECT * INTO prior FROM private_discovery_admin.versions WHERE request_id=p_request_id;
   IF FOUND THEN
     IF prior.actor_id IS DISTINCT FROM actor OR prior.base_revision IS DISTINCT FROM p_expected_revision
       OR prior.payload IS DISTINCT FROM p_payload OR prior.reason IS DISTINCT FROM btrim(p_reason) THEN
       RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='draft_request_reused';
     END IF;
   ELSE
     IF current_draft.revision<>p_expected_revision THEN
       RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='draft_revision_conflict';
     END IF;
     IF current_draft.revision>=2147483647 THEN
       RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='draft_revision_limit';
     END IF;
     IF (p_payload-ARRAY['places','sources','packages','inventory']) IS DISTINCT FROM (current_draft.payload-ARRAY['places','sources','packages','inventory']) THEN
       RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='draft_envelope';
     END IF;
     PERFORM private_discovery_admin.sync_inventory(p_payload,current_draft.payload);
     INSERT INTO private_discovery_admin.versions(revision,base_revision,request_id,actor_id,reason,payload,payload_hash)
       VALUES(current_draft.revision+1,current_draft.revision,p_request_id,actor,btrim(p_reason),p_payload,md5(p_payload::text));
     UPDATE private_discovery_admin.draft SET revision=revision+1,payload=p_payload,
       updated_by=actor,updated_at=now() WHERE singleton RETURNING * INTO current_draft;
   END IF;
 ELSIF p_action='version' THEN
   SELECT * INTO snapshot FROM private_discovery_admin.versions WHERE revision=p_revision;
   IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='draft_version_missing'; END IF;
   RETURN jsonb_build_object('revision',snapshot.revision,'payload',snapshot.payload,
     'updatedBy',snapshot.actor_id,'updatedAt',snapshot.changed_at,'reason',snapshot.reason);
 ELSE SELECT * INTO current_draft FROM private_discovery_admin.draft WHERE singleton;
 END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY v.revision DESC),'[]'::jsonb) INTO history FROM
  (SELECT revision,base_revision AS "baseRevision",actor_id AS "actorId",reason,
    changed_at AS "changedAt",payload_hash AS "payloadHash"
   FROM private_discovery_admin.versions ORDER BY revision DESC LIMIT 50) v;
 RETURN jsonb_build_object('revision',current_draft.revision,'payload',current_draft.payload,
   'updatedBy',current_draft.updated_by,'updatedAt',current_draft.updated_at,'history',history);
END $endpoint$;
REVOKE ALL ON FUNCTION private_discovery_admin.endpoint(text,jsonb,bigint,text,uuid,bigint) FROM PUBLIC,anon,authenticated,service_role;
GRANT USAGE ON SCHEMA private_discovery_admin TO authenticated;
GRANT EXECUTE ON FUNCTION private_discovery_admin.endpoint(text,jsonb,bigint,text,uuid,bigint) TO authenticated;
-- Exposed wrapper has no elevated privileges. Its private entry checks the
-- protected profile AND a live matching Auth session before every read/write.
CREATE FUNCTION public.admin_discovery(
 p_action text DEFAULT 'read',p_payload jsonb DEFAULT NULL,
 p_expected_revision bigint DEFAULT NULL,p_reason text DEFAULT NULL,
 p_request_id uuid DEFAULT NULL,p_revision bigint DEFAULT NULL)
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $wrapper$
 SELECT private_discovery_admin.endpoint(p_action,p_payload,p_expected_revision,p_reason,p_request_id,p_revision);
$wrapper$;
REVOKE ALL ON FUNCTION public.admin_discovery(text,jsonb,bigint,text,uuid,bigint) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.admin_discovery(text,jsonb,bigint,text,uuid,bigint) TO authenticated;
NOTIFY pgrst,'reload schema';
COMMIT;
