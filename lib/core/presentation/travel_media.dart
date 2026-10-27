/// Presentation references only. Never included in a trip payload or its digest.
class TravelMediaReference {
  final String imageUrl, sourceUrl, author, license, caption;
  final String? licenseUrl;
  final String? declaredPermission;

  const TravelMediaReference({
    required this.imageUrl,
    required this.sourceUrl,
    required this.author,
    required this.license,
    this.licenseUrl,
    required this.caption,
    this.declaredPermission,
  });
}

/// Commons imageinfo/description pages checked 2026-10-16. Provider thumbnails
/// are displayed without modifying source files; the UI explains its crop.
class TravelMediaCatalog {
  TravelMediaCatalog._();

  static TravelMediaReference _commons(
    String path,
    String author,
    String license,
    String licensePath,
    String caption,
  ) => TravelMediaReference(
    imageUrl:
        'https://thumb.wikimedia.org/wikipedia/commons/thumb/$path/1280px-${path.split('/').last}',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:${path.split('/').last}',
    author: author,
    license: license,
    licenseUrl: 'https://creativecommons.org/$licensePath/',
    caption: caption,
  );

  static final Map<String, TravelMediaReference> _destinations =
      Map.unmodifiable({
        'ha-noi': _commons(
          '8/83/Night_skyline_%284856118316%29.jpg',
          'Caitriana Nicholson',
          'CC BY-SA 2.0',
          'licenses/by-sa/2.0',
          'Hồ Hoàn Kiếm, Hà Nội',
        ),
        'ha-long': _commons(
          '0/04/H%E1%BA%A1_Long_Bay_Panorama%2C_Vietnam.jpg',
          'Mustang Joe',
          'CC0',
          'publicdomain/zero/1.0',
          'Vịnh Hạ Long',
        ),
        'sa-pa': _commons(
          '3/38/Road_and_paddy_fields_in_Sa_Pa%2C_Vietnam%2C_20240126_1202_3586.jpg',
          'Jakub Hałun',
          'CC BY 4.0',
          'licenses/by/4.0',
          'Đường và ruộng bậc thang gần Sa Pa',
        ),
        'ninh-binh': _commons(
          '9/9c/Trang_An_Landscape_Complex%2C_Ninh_Binh_Province%2C_Vietnam%2C_20240202_1447_5310.jpg',
          'Jakub Hałun',
          'CC BY 4.0',
          'licenses/by/4.0',
          'Quần thể danh thắng Tràng An, Ninh Bình',
        ),
        'hue': _commons(
          '0/0e/Ngo_Mon.jpg',
          'Lưu Ly',
          'CC BY-SA 3.0',
          'licenses/by-sa/3.0',
          'Ngọ Môn, Kinh thành Huế',
        ),
        'da-nang': _commons(
          'd/d9/Da_Nang_Dragon_Bridge.jpg',
          'Person-with-No Name',
          'CC BY 2.0',
          'licenses/by/2.0',
          'Cầu Rồng, Đà Nẵng',
        ),
        'hoi-an': _commons(
          '6/61/Hoi%27an_by_the_river.jpg',
          'John Lian',
          'CC BY-SA 4.0',
          'licenses/by-sa/4.0',
          'Hội An bên sông lúc chiều tối',
        ),
        'nha-trang': _commons(
          'd/d7/Nhatrang_Beach_at_night.jpg',
          'startracker',
          'CC BY-SA 2.0',
          'licenses/by-sa/2.0',
          'Bãi biển Nha Trang về đêm',
        ),
        'da-lat': _commons(
          'a/aa/Da_Lat_-_Xuan_Huong_Lake.jpg',
          'P. Hughes',
          'CC BY 4.0',
          'licenses/by/4.0',
          'Hồ Xuân Hương, Đà Lạt',
        ),
        'ho-chi-minh': _commons(
          'c/c3/Saigon_sunset_np.JPG',
          'Nic saigon',
          'CC BY-SA 3.0',
          'licenses/by-sa/3.0',
          'Hoàng hôn ở trung tâm TP. Hồ Chí Minh',
        ),
        'phu-quoc': _commons(
          '1/1d/Phu_Quoc_beach_01.jpg',
          'Elmschrat',
          'CC BY-SA 4.0',
          'licenses/by-sa/4.0',
          'Bãi biển Phú Quốc',
        ),
        'can-tho': _commons(
          '1/12/Cai_Rang_floating_market%2C_Can_Tho_%2844294953560%29.jpg',
          'Isabell Schulz',
          'CC BY-SA 2.0',
          'licenses/by-sa/2.0',
          'Chợ nổi Cái Răng, Cần Thơ',
        ),
      });

  static TravelMediaReference? forDestination(String? id) => _destinations[id];

  static TravelMediaReference? fromPublished({
    required String? imageUrl,
    required Map<String, Object?>? rights,
    required String caption,
  }) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    if (rights == null || rights.isEmpty) return null;

    final sourceUrl = rights['sourceUrl'] as String? ?? '';
    final permission = rights['permission'] as String? ?? '';
    final credit = rights['credit'] as String? ?? '';
    final rawLicenseUrl = rights['licenseUrl'] as String?;

    if (sourceUrl.isEmpty || credit.isEmpty || permission.isEmpty) return null;

    if (permission == 'licensed') {
      if (rawLicenseUrl == null || rawLicenseUrl.trim().isEmpty) {
        return null;
      }
    }

    final String? licenseUrl = permission == 'owned' ? null : rawLicenseUrl;
    final String licenseName = switch (permission) {
      'owned' => 'Bản quyền tác giả',
      'public_domain' => 'Phạm vi công cộng',
      'licensed' => 'Theo giấy phép đính kèm',
      _ => 'Khai báo quản trị',
    };

    return TravelMediaReference(
      imageUrl: imageUrl,
      sourceUrl: sourceUrl,
      author: credit,
      license: licenseName,
      licenseUrl: licenseUrl,
      caption: caption,
      declaredPermission: permission,
    );
  }

  // Only known photo subjects match these stable catalogue IDs. Other
  // activities must not inherit a destination cover as their own place photo.
  static TravelMediaReference? forPlace(String? id) => switch (id) {
    'ha-noi/hoan-kiem' => _destinations['ha-noi'],
    'hue/citadel' => _destinations['hue'],
    _ => null,
  };
}
