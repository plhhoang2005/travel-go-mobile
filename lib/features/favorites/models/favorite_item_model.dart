class FavoriteItem {
  final String id;
  final String userId;
  final String itemId;
  final String itemType; // destination, hotel, tour
  final String title;
  final String? location;
  final String? imageUrl;
  final double price;
  final double rating;
  final DateTime createdAt;

  const FavoriteItem({
    required this.id,
    required this.userId,
    required this.itemId,
    this.itemType = 'hotel',
    required this.title,
    this.location,
    this.imageUrl,
    this.price = 0,
    this.rating = 5.0,
    required this.createdAt,
  });

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      itemId: json['item_id'] as String? ?? '',
      itemType: json['item_type'] as String? ?? 'hotel',
      title: json['title'] as String? ?? '',
      location: json['location'] as String?,
      imageUrl: json['image_url'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'item_id': itemId,
      'item_type': itemType,
      'title': title,
      'location': location,
      'image_url': imageUrl,
      'price': price,
      'rating': rating,
    };
  }
}
