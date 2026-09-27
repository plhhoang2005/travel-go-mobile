class DestinationModel {
  final String id;
  final String name;
  final String region;
  final String? description;
  final String? imageUrl;
  final double weatherCachedTemp;
  final bool isPopular;

  const DestinationModel({
    required this.id,
    required this.name,
    required this.region,
    this.description,
    this.imageUrl,
    this.weatherCachedTemp = 26.0,
    this.isPopular = true,
  });

  factory DestinationModel.fromJson(Map<String, dynamic> json) {
    return DestinationModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      region: json['region'] as String? ?? 'Toàn quốc',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      weatherCachedTemp: (json['weather_cached_temp'] as num?)?.toDouble() ?? 26.0,
      isPopular: json['is_popular'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'region': region,
      'description': description,
      'image_url': imageUrl,
      'weather_cached_temp': weatherCachedTemp,
      'is_popular': isPopular,
    };
  }

  static List<DestinationModel> presetFallbackList() {
    return const [
      DestinationModel(
        id: 'da-nang',
        name: 'Đà Nẵng',
        region: 'Trung',
        description: 'Thành phố đáng sống với biển Mỹ Khê và Cầu Vàng Bà Nà Hills',
        imageUrl: 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800',
        weatherCachedTemp: 28.5,
      ),
      DestinationModel(
        id: 'da-lat',
        name: 'Đà Lạt',
        region: 'Tây Nguyên',
        description: 'Thành phố ngàn hoa với khí hậu se lạnh và cảnh sắc thơ mộng',
        imageUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800',
        weatherCachedTemp: 20.0,
      ),
      DestinationModel(
        id: 'phu-quoc',
        name: 'Phú Quốc',
        region: 'Nam',
        description: 'Đảo ngọc hoang sơ với bãi biển cát trắng và hoàng hôn rực rỡ',
        imageUrl: 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800',
        weatherCachedTemp: 30.0,
      ),
      DestinationModel(
        id: 'sa-pa',
        name: 'Sa Pa',
        region: 'Bắc',
        description: 'Thung lũng Mường Hoa, đỉnh Fansipan và ruộng bậc thang hùng vĩ',
        imageUrl: 'https://images.unsplash.com/photo-1570789210967-2cac24afeb00?w=800',
        weatherCachedTemp: 16.0,
      ),
      DestinationModel(
        id: 'nha-trang',
        name: 'Nha Trang',
        region: 'Trung',
        description: 'Vịnh biển tuyệt đẹp với nhiều rạn san hô và hải sản tươi sống',
        imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
        weatherCachedTemp: 29.0,
      ),
      DestinationModel(
        id: 'hoi-an',
        name: 'Hội An',
        region: 'Trung',
        description: 'Phố cổ đèn lồng di sản thế giới lung linh bên dòng sông Hoài',
        imageUrl: 'https://images.unsplash.com/photo-1528127269322-539801943592?w=800',
        weatherCachedTemp: 28.0,
      ),
    ];
  }
}
