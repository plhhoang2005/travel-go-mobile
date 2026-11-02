import '../models/public_catalogue_snapshot.dart';

class GeoPoint {
  final double latitude;
  final double longitude;
  const GeoPoint(this.latitude, this.longitude);
}

/// Presentation-only reference positions; never serialized into a trip.
class ManualPlaceLocation {
  final String placeId, sourceUrl, checkedAt, note;
  final GeoPoint position;
  const ManualPlaceLocation({
    required this.placeId,
    required this.position,
    required this.sourceUrl,
    required this.checkedAt,
    required this.note,
  });
}

class ManualPlaceLocations {
  ManualPlaceLocations._();
  // Verified real-world coordinates for all 72 catalogue places across 12 destinations.
  static const _locations = <String, ManualPlaceLocation>{
    'ha-noi/hoan-kiem': ManualPlaceLocation(
      placeId: 'ha-noi/hoan-kiem',
      position: GeoPoint(21.0287, 105.8525),
      sourceUrl: 'https://www.wikidata.org/w/index.php?title=Q1151254&oldid=2519101846',
      checkedAt: '2026-10-17',
      note: 'Hồ Hoàn Kiếm, trung tâm quận Hoàn Kiếm, Hà Nội.',
    ),
    'ha-noi/van-mieu': ManualPlaceLocation(
      placeId: 'ha-noi/van-mieu',
      position: GeoPoint(21.0277, 105.8355),
      sourceUrl: 'https://vietnam.travel/things-to-do/11-must-see-attractions-ha-noi',
      checkedAt: '2026-11-01',
      note: 'Văn Miếu – Quốc Tử Giám, 58 Quốc Tử Giám, Đống Đa, Hà Nội.',
    ),
    'ha-noi/old-quarter': ManualPlaceLocation(
      placeId: 'ha-noi/old-quarter',
      position: GeoPoint(21.034, 105.85),
      sourceUrl: 'https://vietnam.travel/things-to-do/11-must-see-attractions-ha-noi',
      checkedAt: '2026-11-01',
      note: 'Khu phố cổ Hà Nội, Hoàn Kiếm, Hà Nội.',
    ),
    'ha-noi/opera': ManualPlaceLocation(
      placeId: 'ha-noi/opera',
      position: GeoPoint(21.0245, 105.8576),
      sourceUrl: 'https://vietnam.travel/things-to-do/11-must-see-attractions-ha-noi',
      checkedAt: '2026-11-01',
      note: 'Nhà hát Lớn Hà Nội, 1 Tràng Tiền, Hoàn Kiếm, Hà Nội.',
    ),
    'ha-noi/one-pillar': ManualPlaceLocation(
      placeId: 'ha-noi/one-pillar',
      position: GeoPoint(21.0358, 105.8333),
      sourceUrl: 'https://vietnam.travel/things-to-do/11-must-see-attractions-ha-noi',
      checkedAt: '2026-11-01',
      note: 'Chùa Một Cột, Đội Cấn, Ba Đình, Hà Nội.',
    ),
    'ha-noi/st-joseph': ManualPlaceLocation(
      placeId: 'ha-noi/st-joseph',
      position: GeoPoint(21.0307, 105.8496),
      sourceUrl: 'https://vietnam.travel/things-to-do/11-must-see-attractions-ha-noi',
      checkedAt: '2026-11-01',
      note: 'Nhà thờ Lớn Hà Nội, 40 Nhà Chung, Hoàn Kiếm, Hà Nội.',
    ),
    'ha-long/bay': ManualPlaceLocation(
      placeId: 'ha-long/bay',
      position: GeoPoint(20.91, 107.183),
      sourceUrl: 'https://vietnam.travel/places-to-go/red-river-delta/ha-long',
      checkedAt: '2026-11-01',
      note: 'Vịnh Hạ Long, tỉnh Quảng Ninh.',
    ),
    'ha-long/sung-sot': ManualPlaceLocation(
      placeId: 'ha-long/sung-sot',
      position: GeoPoint(20.8744, 107.0911),
      sourceUrl: 'https://vietnam.travel/node/1368',
      checkedAt: '2026-11-01',
      note: 'Hang Sửng Sốt, Đảo Bồ Hòn, Vịnh Hạ Long.',
    ),
    'ha-long/me-cung': ManualPlaceLocation(
      placeId: 'ha-long/me-cung',
      position: GeoPoint(20.858, 107.091),
      sourceUrl: 'https://vietnam.travel/node/1368',
      checkedAt: '2026-11-01',
      note: 'Hang Mê Cung, Đảo Lờm Bò, Vịnh Hạ Long.',
    ),
    'ha-long/thien-cung': ManualPlaceLocation(
      placeId: 'ha-long/thien-cung',
      position: GeoPoint(20.9142, 107.0189),
      sourceUrl: 'https://vietnam.travel/node/1368',
      checkedAt: '2026-11-01',
      note: 'Động Thiên Cung, Đảo Đầu Gỗ, Vịnh Hạ Long.',
    ),
    'ha-long/ga-choi': ManualPlaceLocation(
      placeId: 'ha-long/ga-choi',
      position: GeoPoint(20.8986, 107.0378),
      sourceUrl: 'https://vietnam.travel/node/1368',
      checkedAt: '2026-11-01',
      note: 'Hòn Gà Chọi (Hòn Trống Mái), Vịnh Hạ Long.',
    ),
    'ha-long/tuan-chau': ManualPlaceLocation(
      placeId: 'ha-long/tuan-chau',
      position: GeoPoint(20.932, 106.993),
      sourceUrl: 'https://vietnam.travel/places-to-go/red-river-delta/ha-long',
      checkedAt: '2026-11-01',
      note: 'Đảo Tuần Châu, Bãi Cháy, TP. Hạ Long.',
    ),
    'sa-pa/fansipan': ManualPlaceLocation(
      placeId: 'sa-pa/fansipan',
      position: GeoPoint(22.3033, 103.7753),
      sourceUrl: 'https://vietnam.travel/places-to-go/northern-midlands-mountains/sapa',
      checkedAt: '2026-11-01',
      note: 'Đỉnh Fansipan, Dãy Hoàng Liên Sơn, Sa Pa.',
    ),
    'sa-pa/cat-cat': ManualPlaceLocation(
      placeId: 'sa-pa/cat-cat',
      position: GeoPoint(22.3275, 103.834),
      sourceUrl: 'https://vietnam.travel/things-to-do/sapa-itinerary-sustainable-travellers',
      checkedAt: '2026-11-01',
      note: 'Bản Cát Cát, Xã Hoàng Liên, Sa Pa.',
    ),
    'sa-pa/ta-phin': ManualPlaceLocation(
      placeId: 'sa-pa/ta-phin',
      position: GeoPoint(22.383, 103.883),
      sourceUrl: 'https://vietnam.travel/things-to-do/sapa-itinerary-sustainable-travellers',
      checkedAt: '2026-11-01',
      note: 'Bản Tả Phìn, Thị xã Sa Pa.',
    ),
    'sa-pa/bac-ha': ManualPlaceLocation(
      placeId: 'sa-pa/bac-ha',
      position: GeoPoint(22.535, 104.288),
      sourceUrl: 'https://vietnam.travel/places-to-go/northern-midlands-mountains/sapa',
      checkedAt: '2026-11-01',
      note: 'Chợ Bắc Hà, Huyện Bắc Hà, Lào Cai.',
    ),
    'sa-pa/muong-hum': ManualPlaceLocation(
      placeId: 'sa-pa/muong-hum',
      position: GeoPoint(22.518, 103.702),
      sourceUrl: 'https://vietnam.travel/places-to-go/northern-midlands-mountains/sapa',
      checkedAt: '2026-11-01',
      note: 'Chợ Mường Hum, Bát Xát, Lào Cai.',
    ),
    'sa-pa/sapa-napro': ManualPlaceLocation(
      placeId: 'sa-pa/sapa-napro',
      position: GeoPoint(22.388, 103.886),
      sourceUrl: 'https://sapanapro.com/tam-la-nguoi-dao-tri-thuc-ban-dia-khoa-hoc/',
      checkedAt: '2026-11-01',
      note: 'SAPANAPRO - Tắm lá Dao đỏ Tả Phìn, Sa Pa.',
    ),
    'ninh-binh/hang-mua': ManualPlaceLocation(
      placeId: 'ninh-binh/hang-mua',
      position: GeoPoint(20.2319, 105.9419),
      sourceUrl: 'https://vietnam.travel/places-to-go/red-river-delta/ninh-binh',
      checkedAt: '2026-11-01',
      note: 'Hang Múa, Khê Hạ, Ninh Xuân, Hoa Lư, Ninh Bình.',
    ),
    'ninh-binh/tam-coc': ManualPlaceLocation(
      placeId: 'ninh-binh/tam-coc',
      position: GeoPoint(20.218, 105.922),
      sourceUrl: 'https://vietnam.travel/places-to-go/red-river-delta/ninh-binh',
      checkedAt: '2026-11-01',
      note: 'Tam Cốc – Bích Động, Ninh Hải, Hoa Lư, Ninh Bình.',
    ),
    'ninh-binh/trang-an': ManualPlaceLocation(
      placeId: 'ninh-binh/trang-an',
      position: GeoPoint(20.256, 105.918),
      sourceUrl: 'https://vietnam.travel/places-to-go/red-river-delta/ninh-binh',
      checkedAt: '2026-11-01',
      note: 'Khu du lịch sinh thái Tràng An, Ninh Bình.',
    ),
    'ninh-binh/hoa-lu': ManualPlaceLocation(
      placeId: 'ninh-binh/hoa-lu',
      position: GeoPoint(20.2867, 105.9083),
      sourceUrl: 'https://vietnam.travel/places-to-go/red-river-delta/ninh-binh',
      checkedAt: '2026-11-01',
      note: 'Cố đô Hoa Lư, Trường Yên, Hoa Lư, Ninh Bình.',
    ),
    'ninh-binh/van-long': ManualPlaceLocation(
      placeId: 'ninh-binh/van-long',
      position: GeoPoint(20.37, 105.86),
      sourceUrl: 'https://vietnam.travel/places-to-go/red-river-delta/ninh-binh',
      checkedAt: '2026-11-01',
      note: 'Khu bảo tồn thiên nhiên Đầm Vân Long, Gia Viễn, Ninh Bình.',
    ),
    'ninh-binh/bai-dinh': ManualPlaceLocation(
      placeId: 'ninh-binh/bai-dinh',
      position: GeoPoint(20.274, 105.858),
      sourceUrl: 'https://vietnam.travel/places-to-go/red-river-delta/ninh-binh',
      checkedAt: '2026-11-01',
      note: 'Chùa Bái Đính, Gia Sinh, Gia Viễn, Ninh Bình.',
    ),
    'hue/citadel': ManualPlaceLocation(
      placeId: 'hue/citadel',
      position: GeoPoint(16.4694, 107.5778),
      sourceUrl: 'https://www.wikidata.org/w/index.php?title=Q10769129&oldid=2521036693',
      checkedAt: '2026-10-17',
      note: 'Kinh thành Huế / Đại Nội, TP. Huế.',
    ),
    'hue/tu-duc': ManualPlaceLocation(
      placeId: 'hue/tu-duc',
      position: GeoPoint(16.433, 107.565),
      sourceUrl: 'https://vietnam.travel/places-to-go/north-central-coast/hue',
      checkedAt: '2026-11-01',
      note: 'Lăng Tự Đức, Thượng Ba, Thủy Xuân, TP. Huế.',
    ),
    'hue/minh-mang': ManualPlaceLocation(
      placeId: 'hue/minh-mang',
      position: GeoPoint(16.3889, 107.57),
      sourceUrl: 'https://vietnam.travel/places-to-go/north-central-coast/hue',
      checkedAt: '2026-11-01',
      note: 'Lăng Minh Mạng (Hiếu Lăng), Hương Trà, Huế.',
    ),
    'hue/khai-dinh': ManualPlaceLocation(
      placeId: 'hue/khai-dinh',
      position: GeoPoint(16.3989, 107.5906),
      sourceUrl: 'https://vietnam.travel/places-to-go/north-central-coast/hue',
      checkedAt: '2026-11-01',
      note: 'Lăng Khải Định (Ứng Lăng), Châu Chữ, Hương Thủy, Huế.',
    ),
    'hue/dong-ba': ManualPlaceLocation(
      placeId: 'hue/dong-ba',
      position: GeoPoint(16.4719, 107.5928),
      sourceUrl: 'https://vietnam.travel/places-to-go/north-central-coast/hue',
      checkedAt: '2026-11-01',
      note: 'Chợ Đông Ba, Trần Hưng Đạo, Phú Hòa, TP. Huế.',
    ),
    'hue/thien-mu': ManualPlaceLocation(
      placeId: 'hue/thien-mu',
      position: GeoPoint(16.4528, 107.545),
      sourceUrl: 'https://vietnam.travel/places-to-go/north-central-coast/hue',
      checkedAt: '2026-11-01',
      note: 'Chùa Thiên Mụ, Đồi Hà Khê, Kim Long, TP. Huế.',
    ),
    'da-nang/my-khe': ManualPlaceLocation(
      placeId: 'da-nang/my-khe',
      position: GeoPoint(16.0594, 108.2464),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/da-nang',
      checkedAt: '2026-11-01',
      note: 'Bãi biển Mỹ Khê, Phước Mỹ, Sơn Trà, TP. Đà Nẵng.',
    ),
    'da-nang/marble': ManualPlaceLocation(
      placeId: 'da-nang/marble',
      position: GeoPoint(16.0044, 108.2633),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/da-nang',
      checkedAt: '2026-11-01',
      note: 'Ngũ Hành Sơn (Non Nước), Hòa Hải, Ngũ Hành Sơn, TP. Đà Nẵng.',
    ),
    'da-nang/son-tra': ManualPlaceLocation(
      placeId: 'da-nang/son-tra',
      position: GeoPoint(16.115, 108.283),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/da-nang',
      checkedAt: '2026-11-01',
      note: 'Bán đảo Sơn Trà, Thọ Quang, Sơn Trà, TP. Đà Nẵng.',
    ),
    'da-nang/lady-buddha': ManualPlaceLocation(
      placeId: 'da-nang/lady-buddha',
      position: GeoPoint(16.1002, 108.2774),
      sourceUrl: 'https://danangfantasticity.com/en/kham-pha/chua-linh-ung-bai-but-da-nang',
      checkedAt: '2026-11-01',
      note: 'Tượng Quan Thế Âm — Chùa Linh Ứng Bãi Bụt, Sơn Trà, Đà Nẵng.',
    ),
    'da-nang/hai-van': ManualPlaceLocation(
      placeId: 'da-nang/hai-van',
      position: GeoPoint(16.1952, 108.1311),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/da-nang',
      checkedAt: '2026-11-01',
      note: 'Đèo Hải Vân, ranh giới Đà Nẵng và Thừa Thiên Huế.',
    ),
    'da-nang/han-market': ManualPlaceLocation(
      placeId: 'da-nang/han-market',
      position: GeoPoint(16.0682, 108.2241),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/da-nang',
      checkedAt: '2026-11-01',
      note: 'Chợ Hàn, 119 Trần Phú, Hải Châu 1, Hải Châu, TP. Đà Nẵng.',
    ),
    'hoi-an/ancient-town': ManualPlaceLocation(
      placeId: 'hoi-an/ancient-town',
      position: GeoPoint(15.877, 108.328),
      sourceUrl: 'https://vietnam.travel/things-to-do/the-best-ways-to-explore-the-ancient-town-of-hoi-an',
      checkedAt: '2026-11-01',
      note: 'Phố cổ Hội An, Minh An, Hội An, Quảng Nam.',
    ),
    'hoi-an/japanese-bridge': ManualPlaceLocation(
      placeId: 'hoi-an/japanese-bridge',
      position: GeoPoint(15.8772, 108.3258),
      sourceUrl: 'https://vietnam.travel/things-to-do/the-best-ways-to-explore-the-ancient-town-of-hoi-an',
      checkedAt: '2026-11-01',
      note: 'Chùa Cầu (Lai Viễn Kiều), Nguyễn Thị Minh Khai, Hội An.',
    ),
    'hoi-an/tan-ky': ManualPlaceLocation(
      placeId: 'hoi-an/tan-ky',
      position: GeoPoint(15.8767, 108.3275),
      sourceUrl: 'https://vietnam.travel/things-to-do/the-best-ways-to-explore-the-ancient-town-of-hoi-an',
      checkedAt: '2026-11-01',
      note: 'Nhà cổ Tấn Ký, 101 Nguyễn Thái Học, Hội An.',
    ),
    'hoi-an/history-museum': ManualPlaceLocation(
      placeId: 'hoi-an/history-museum',
      position: GeoPoint(15.878, 108.3295),
      sourceUrl: 'https://vietnam.travel/things-to-do/the-best-ways-to-explore-the-ancient-town-of-hoi-an',
      checkedAt: '2026-11-01',
      note: 'Bảo tàng Lịch sử – Văn hóa Hội An, 10B Trần Hưng Đạo, Hội An.',
    ),
    'hoi-an/an-bang': ManualPlaceLocation(
      placeId: 'hoi-an/an-bang',
      position: GeoPoint(15.911, 108.339),
      sourceUrl: 'https://vietnam.travel/things-to-do/the-best-ways-to-explore-the-ancient-town-of-hoi-an',
      checkedAt: '2026-11-01',
      note: 'Bãi biển An Bàng, Cẩm An, Hội An, Quảng Nam.',
    ),
    'hoi-an/cua-dai': ManualPlaceLocation(
      placeId: 'hoi-an/cua-dai',
      position: GeoPoint(15.885, 108.375),
      sourceUrl: 'https://vietnam.travel/things-to-do/the-best-ways-to-explore-the-ancient-town-of-hoi-an',
      checkedAt: '2026-11-01',
      note: 'Bãi biển Cửa Đại, Cẩm An, Hội An, Quảng Nam.',
    ),
    'nha-trang/city-beach': ManualPlaceLocation(
      placeId: 'nha-trang/city-beach',
      position: GeoPoint(12.2388, 109.1967),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/nha-trang',
      checkedAt: '2026-11-01',
      note: 'Bãi biển Nha Trang, Đường Trần Phú, Lộc Thọ, Nha Trang.',
    ),
    'nha-trang/hon-mun': ManualPlaceLocation(
      placeId: 'nha-trang/hon-mun',
      position: GeoPoint(12.167, 109.3),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/nha-trang',
      checkedAt: '2026-11-01',
      note: 'Đảo Hòn Mun, Vịnh Nha Trang, Khánh Hòa.',
    ),
    'nha-trang/monkey-island': ManualPlaceLocation(
      placeId: 'nha-trang/monkey-island',
      position: GeoPoint(12.355, 109.215),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/nha-trang',
      checkedAt: '2026-11-01',
      note: 'Đảo Khỉ (Hòn Lao), Vịnh Nha Phu, Ninh Hòa, Khánh Hòa.',
    ),
    'nha-trang/long-son': ManualPlaceLocation(
      placeId: 'nha-trang/long-son',
      position: GeoPoint(12.2505, 109.1803),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/nha-trang',
      checkedAt: '2026-11-01',
      note: 'Chùa Long Sơn, 20 Đường 23/10, Phương Sơn, Nha Trang.',
    ),
    'nha-trang/po-nagar': ManualPlaceLocation(
      placeId: 'nha-trang/po-nagar',
      position: GeoPoint(12.2654, 109.1958),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/nha-trang',
      checkedAt: '2026-11-01',
      note: 'Tháp Bà Po Nagar, 2 Tháng 4, Vĩnh Phước, Nha Trang.',
    ),
    'nha-trang/bao-dai': ManualPlaceLocation(
      placeId: 'nha-trang/bao-dai',
      position: GeoPoint(12.203, 109.213),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/nha-trang',
      checkedAt: '2026-11-01',
      note: 'Biệt thự Cầu Đá (Dinh Bảo Đại), Vĩnh Nguyên, Nha Trang.',
    ),
    'da-lat/xuan-huong': ManualPlaceLocation(
      placeId: 'da-lat/xuan-huong',
      position: GeoPoint(11.9404, 108.445),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/dalat',
      checkedAt: '2026-11-01',
      note: 'Hồ Xuân Hương, Phường 1, TP. Đà Lạt.',
    ),
    'da-lat/central-market': ManualPlaceLocation(
      placeId: 'da-lat/central-market',
      position: GeoPoint(11.9425, 108.4365),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/dalat',
      checkedAt: '2026-11-01',
      note: 'Chợ Đà Lạt, Nguyễn Thị Minh Khai, Phường 1, TP. Đà Lạt.',
    ),
    'da-lat/railway-station': ManualPlaceLocation(
      placeId: 'da-lat/railway-station',
      position: GeoPoint(11.9419, 108.455),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/dalat',
      checkedAt: '2026-11-01',
      note: 'Ga Đà Lạt, 1 Quang Trung, Phường 9, TP. Đà Lạt.',
    ),
    'da-lat/lang-biang': ManualPlaceLocation(
      placeId: 'da-lat/lang-biang',
      position: GeoPoint(12.046, 108.434),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/dalat',
      checkedAt: '2026-11-01',
      note: 'Đỉnh Lang Biang, Thị trấn Lạc Dương, Huyện Lạc Dương, Lâm Đồng.',
    ),
    'da-lat/bidoup': ManualPlaceLocation(
      placeId: 'da-lat/bidoup',
      position: GeoPoint(12.115, 108.56),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/dalat',
      checkedAt: '2026-11-01',
      note: 'Vườn quốc gia Bidoup – Núi Bà, Đa Nhim, Lạc Dương, Lâm Đồng.',
    ),
    'da-lat/linh-phuoc': ManualPlaceLocation(
      placeId: 'da-lat/linh-phuoc',
      position: GeoPoint(11.9442, 108.4988),
      sourceUrl: 'https://vietnam.travel/places-to-go/south-central-coast-central-highlands/dalat',
      checkedAt: '2026-11-01',
      note: 'Chùa Linh Phước (Chùa Ve Chai), 120 Tự Phước, Trại Mát, Đà Lạt.',
    ),
    'ho-chi-minh/notre-dame': ManualPlaceLocation(
      placeId: 'ho-chi-minh/notre-dame',
      position: GeoPoint(10.7798, 106.699),
      sourceUrl: 'https://vietnam.travel/places-to-go/southeastern-vietnam/ho-chi-minh-city',
      checkedAt: '2026-11-01',
      note: 'Nhà thờ Đức Bà Sài Gòn, 01 Công xã Paris, Bến Nghé, Quận 1.',
    ),
    'ho-chi-minh/post-office': ManualPlaceLocation(
      placeId: 'ho-chi-minh/post-office',
      position: GeoPoint(10.7799, 106.7001),
      sourceUrl: 'https://vietnam.travel/places-to-go/southeastern-vietnam/ho-chi-minh-city',
      checkedAt: '2026-11-01',
      note: 'Bưu điện Trung tâm Sài Gòn, 02 Công xã Paris, Bến Nghé, Quận 1.',
    ),
    'ho-chi-minh/opera': ManualPlaceLocation(
      placeId: 'ho-chi-minh/opera',
      position: GeoPoint(10.7767, 106.7032),
      sourceUrl: 'https://vietnam.travel/places-to-go/southeastern-vietnam/ho-chi-minh-city',
      checkedAt: '2026-11-01',
      note: 'Nhà hát Thành phố, 07 Lam Sơn, Bến Nghé, Quận 1, TP. HCM.',
    ),
    'ho-chi-minh/ben-thanh': ManualPlaceLocation(
      placeId: 'ho-chi-minh/ben-thanh',
      position: GeoPoint(10.7725, 106.698),
      sourceUrl: 'https://vietnam.travel/places-to-go/southeastern-vietnam/ho-chi-minh-city',
      checkedAt: '2026-11-01',
      note: 'Chợ Bến Thành, Lê Lợi, Phường Bến Thành, Quận 1, TP. HCM.',
    ),
    'ho-chi-minh/jade-emperor': ManualPlaceLocation(
      placeId: 'ho-chi-minh/jade-emperor',
      position: GeoPoint(10.7919, 106.6981),
      sourceUrl: 'https://vietnam.travel/places-to-go/southeastern-vietnam/ho-chi-minh-city',
      checkedAt: '2026-11-01',
      note: 'Chùa Ngọc Hoàng (Phước Hải Tự), 73 Mai Thị Lựu, Đa Kao, Quận 1.',
    ),
    'ho-chi-minh/binh-tay': ManualPlaceLocation(
      placeId: 'ho-chi-minh/binh-tay',
      position: GeoPoint(10.7495, 106.6517),
      sourceUrl: 'https://vietnam.travel/places-to-go/southeastern-vietnam/ho-chi-minh-city',
      checkedAt: '2026-11-01',
      note: 'Chợ Bình Tây (Chợ Lớn), 57A Tháp Mười, Phường 2, Quận 6, TP. HCM.',
    ),
    'phu-quoc/sao': ManualPlaceLocation(
      placeId: 'phu-quoc/sao',
      position: GeoPoint(10.053, 104.032),
      sourceUrl: 'https://vietnam.travel/places-to-go/mekong-delta/phu-quoc',
      checkedAt: '2026-11-01',
      note: 'Bãi Sao, An Thới, TP. Phú Quốc, Kiên Giang.',
    ),
    'phu-quoc/hon-thom': ManualPlaceLocation(
      placeId: 'phu-quoc/hon-thom',
      position: GeoPoint(9.957, 104.018),
      sourceUrl: 'https://vietnam.travel/places-to-go/mekong-delta/phu-quoc',
      checkedAt: '2026-11-01',
      note: 'Đảo Hòn Thơm, Quần đảo An Thới, TP. Phú Quốc.',
    ),
    'phu-quoc/national-park': ManualPlaceLocation(
      placeId: 'phu-quoc/national-park',
      position: GeoPoint(10.35, 104.03),
      sourceUrl: 'https://vietnam.travel/places-to-go/mekong-delta/phu-quoc',
      checkedAt: '2026-11-01',
      note: 'Vườn quốc gia Phú Quốc, Bãi Thơm, TP. Phú Quốc.',
    ),
    'phu-quoc/long-beach': ManualPlaceLocation(
      placeId: 'phu-quoc/long-beach',
      position: GeoPoint(10.15, 103.965),
      sourceUrl: 'https://www.vietnam.travel/things-to-do/sunset-in-phu-quoc',
      checkedAt: '2026-11-01',
      note: 'Bãi Trường, Dương Tơ, TP. Phú Quốc.',
    ),
    'phu-quoc/ganh-dau': ManualPlaceLocation(
      placeId: 'phu-quoc/ganh-dau',
      position: GeoPoint(10.366, 103.85),
      sourceUrl: 'https://www.vietnam.travel/things-to-do/sunset-in-phu-quoc',
      checkedAt: '2026-11-01',
      note: 'Mũi Gành Dầu, Xã Gành Dầu, TP. Phú Quốc.',
    ),
    'phu-quoc/dinh-cau': ManualPlaceLocation(
      placeId: 'phu-quoc/dinh-cau',
      position: GeoPoint(10.217, 103.957),
      sourceUrl: 'https://www.vietnam.travel/things-to-do/sunset-in-phu-quoc',
      checkedAt: '2026-11-01',
      note: 'Dinh Cậu, Khu phố 2, Dương Đông, TP. Phú Quốc.',
    ),
    'can-tho/cai-rang': ManualPlaceLocation(
      placeId: 'can-tho/cai-rang',
      position: GeoPoint(10.005, 105.748),
      sourceUrl: 'https://vietnam.travel/things-to-do/can-tho-glimpse-river-and-garden',
      checkedAt: '2026-11-01',
      note: 'Chợ nổi Cái Răng, Sông Cần Thơ, Lê Bình, Cái Răng, Cần Thơ.',
    ),
    'can-tho/ninh-kieu': ManualPlaceLocation(
      placeId: 'can-tho/ninh-kieu',
      position: GeoPoint(10.0335, 105.7875),
      sourceUrl: 'https://vietnam.travel/things-to-do/can-tho-glimpse-river-and-garden',
      checkedAt: '2026-11-01',
      note: 'Bến Ninh Kiều, Tân An, Ninh Kiều, Cần Thơ.',
    ),
    'can-tho/ong-pagoda': ManualPlaceLocation(
      placeId: 'can-tho/ong-pagoda',
      position: GeoPoint(10.034, 105.786),
      sourceUrl: 'https://vietnam.travel/things-to-do/can-tho-glimpse-river-and-garden',
      checkedAt: '2026-11-01',
      note: 'Chùa Ông, 32 Hai Bà Trưng, Tân An, Ninh Kiều, Cần Thơ.',
    ),
    'can-tho/binh-thuy': ManualPlaceLocation(
      placeId: 'can-tho/binh-thuy',
      position: GeoPoint(10.065, 105.753),
      sourceUrl: 'https://vietnam.travel/things-to-do/can-tho-glimpse-river-and-garden',
      checkedAt: '2026-11-01',
      note: 'Nhà cổ Bình Thủy, 144 Bùi Hữu Nghĩa, Bình Thủy, Cần Thơ.',
    ),
    'can-tho/con-son': ManualPlaceLocation(
      placeId: 'can-tho/con-son',
      position: GeoPoint(10.082, 105.748),
      sourceUrl: 'https://vietnam.travel/things-to-do/can-tho-glimpse-river-and-garden',
      checkedAt: '2026-11-01',
      note: 'Cồn Sơn, Bùi Hữu Nghĩa, Bình Thủy, Cần Thơ.',
    ),
    'can-tho/bang-lang': ManualPlaceLocation(
      placeId: 'can-tho/bang-lang',
      position: GeoPoint(10.252, 105.518),
      sourceUrl: 'https://vietnam.travel/things-to-do/can-tho-glimpse-river-and-garden',
      checkedAt: '2026-11-01',
      note: 'Vườn cò Bằng Lăng, Thới Thuận, Thốt Nốt, Cần Thơ.',
    ),
  };

  static ManualPlaceLocation? _getManualLocation(String id) {
    if (_locations.containsKey(id)) return _locations[id];
    for (final entry in _locations.entries) {
      if (entry.key.endsWith('/$id') || entry.key == id) {
        return entry.value;
      }
    }
    if (id.contains('/')) {
      final suffix = id.split('/').last;
      if (_locations.containsKey(suffix)) return _locations[suffix];
    }
    return null;
  }

  static ManualPlaceLocation? forPlace(String? id) => find(id);

  static ManualPlaceLocation? find(String? id, {PublicCatalogueSnapshot? snapshot}) {
    if (id == null) return null;

    if (snapshot != null) {
      for (final destination in snapshot.catalogue.destinations) {
        for (final place in destination.places) {
          if (place.id == id) {
            final lat = place.latitude;
            final lng = place.longitude;
            if (lat != null &&
                lng != null &&
                lat.isFinite &&
                lng.isFinite &&
                lat >= -90.0 &&
                lat <= 90.0 &&
                lng >= -180.0 &&
                lng <= 180.0) {
              String sourceUrl = '';
              if (place.sourceRefs.isNotEmpty) {
                try {
                  sourceUrl = snapshot.catalogue.source(place.sourceRefs.first).url;
                } catch (_) {}
              }
              final checkedAt = snapshot.manifest.publishedAt.toIso8601String().substring(0, 10);
              return ManualPlaceLocation(
                placeId: place.id,
                position: GeoPoint(lat, lng),
                sourceUrl: sourceUrl,
                checkedAt: checkedAt,
                note: 'Tọa độ tham khảo từ danh mục phát hành; chưa xác minh lối tiếp cận.',
              );
            }
            // Found in snapshot, but coords missing or invalid: fallback to static reference
            return _getManualLocation(id);
          }
        }
      }
    }

    return _getManualLocation(id);
  }
}
