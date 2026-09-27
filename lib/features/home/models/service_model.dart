class ServiceModel {
  final String id;
  final String destinationId;
  final String serviceType;
  final String title;
  final String? description;
  final String? location;
  final double basePrice;
  final double rating;
  final int reviewCount;
  final String? cancellationPolicy;
  final List<String> images;
  final List<String> amenities;
  final bool isFeatured;

  const ServiceModel({
    required this.id,
    required this.destinationId,
    required this.serviceType,
    required this.title,
    this.description,
    this.location,
    required this.basePrice,
    this.rating = 5.0,
    this.reviewCount = 0,
    this.cancellationPolicy,
    this.images = const [],
    this.amenities = const [],
    this.isFeatured = false,
  });

  String? get primaryImage => images.isNotEmpty ? images.first : null;

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String? ?? '',
      destinationId: json['destination_id'] as String? ?? '',
      serviceType: json['service_type'] as String? ?? 'hotel',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      location: json['location'] as String?,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      cancellationPolicy: json['cancellation_policy'] as String?,
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      amenities: (json['amenities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isFeatured: json['is_featured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination_id': destinationId,
      'service_type': serviceType,
      'title': title,
      'description': description,
      'location': location,
      'base_price': basePrice,
      'rating': rating,
      'review_count': reviewCount,
      'cancellation_policy': cancellationPolicy,
      'images': images,
      'amenities': amenities,
      'is_featured': isFeatured,
    };
  }

  static List<ServiceModel> presetHotelsFallback() {
    return const [
      ServiceModel(
        id: 'furama-resort-da-nang',
        destinationId: 'da-nang',
        serviceType: 'hotel',
        title: 'Furama Resort Đà Nẵng',
        description: 'Khu nghỉ dưỡng 5 sao ven biển Mỹ Khê với hồ bơi vô cực và ẩm thực đa dạng.',
        location: 'Võ Nguyên Giáp, Ngũ Hành Sơn, Đà Nẵng',
        basePrice: 2200000,
        rating: 4.8,
        reviewCount: 128,
        cancellationPolicy: 'Miễn phí hủy trước 48h',
        isFeatured: true,
        images: ['https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800'],
        amenities: ['Hồ bơi vô cực', 'Giáp biển', 'Bữa sáng miễn phí', 'Spa & Massage'],
      ),
      ServiceModel(
        id: 'edensee-resort-da-lat',
        destinationId: 'da-lat',
        serviceType: 'hotel',
        title: 'Dalat Edensee Lake Resort & Spa',
        description: 'Nghỉ dưỡng phong cách châu Âu bên bờ hồ Tuyền Lâm mộng mơ.',
        location: 'Khu du lịch Hồ Tuyền Lâm, Đà Lạt',
        basePrice: 1850000,
        rating: 4.7,
        reviewCount: 95,
        cancellationPolicy: 'Miễn phí hủy trước 24h',
        isFeatured: true,
        images: ['https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=800'],
        amenities: ['Bên hồ', 'Bữa sáng', 'Xe đưa đón', 'Sân tennis'],
      ),
      ServiceModel(
        id: 'vinpearl-resort-phu-quoc',
        destinationId: 'phu-quoc',
        serviceType: 'hotel',
        title: 'Vinpearl Resort & Spa Phú Quốc',
        description: 'Khu nghỉ dưỡng sang trọng với bãi biển riêng và công viên nước.',
        location: 'Bãi Dài, Gành Dầu, Phú Quốc',
        basePrice: 2900000,
        rating: 4.9,
        reviewCount: 310,
        cancellationPolicy: 'Miễn phí hủy trước 72h',
        isFeatured: true,
        images: ['https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800'],
        amenities: ['Bãi biển riêng', 'Công viên nước', 'Hồ bơi lớn', 'Buffet'],
      ),
    ];
  }

  static List<ServiceModel> presetToursFallback() {
    return const [
      ServiceModel(
        id: 'tour-bana-hills-01',
        destinationId: 'da-nang',
        serviceType: 'tour',
        title: 'Tour Bà Nà Hills - Cầu Vàng 1 Ngày',
        description: 'Khám phá Cầu Vàng huyền thoại, Làng Pháp và thưởng thức buffet trưa 100 món.',
        location: 'Đà Nẵng',
        basePrice: 1150000,
        rating: 4.9,
        reviewCount: 840,
        cancellationPolicy: 'Miễn phí hủy trước 24h',
        isFeatured: true,
        images: ['https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800'],
        amenities: ['Cáp treo khứ hồi', 'Buffet trưa', 'Xe đưa đón'],
      ),
    ];
  }
}
