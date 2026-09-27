class VoucherModel {
  final String id;
  final String title;
  final double discountAmount;
  final double discountPercent;
  final double minOrderValue;
  final double? maxDiscount;
  final DateTime expiryDate;
  final bool isActive;

  const VoucherModel({
    required this.id,
    required this.title,
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.minOrderValue = 0,
    this.maxDiscount,
    required this.expiryDate,
    this.isActive = true,
  });

  String get discountDisplay {
    if (discountAmount > 0) {
      final k = (discountAmount / 1000).toInt();
      return '$k.000₫';
    }
    if (discountPercent > 0) {
      return '${discountPercent.toInt()}%';
    }
    return 'Ưu đãi';
  }

  factory VoucherModel.fromJson(Map<String, dynamic> json) {
    return VoucherModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 0.0,
      minOrderValue: (json['min_order_value'] as num?)?.toDouble() ?? 0.0,
      maxDiscount: (json['max_discount'] as num?)?.toDouble(),
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'discount_amount': discountAmount,
      'discount_percent': discountPercent,
      'min_order_value': minOrderValue,
      'max_discount': maxDiscount,
      'expiry_date': expiryDate.toIso8601String(),
      'is_active': isActive,
    };
  }

  static List<VoucherModel> presetFallbackList() {
    return [
      VoucherModel(
        id: 'HELLO25',
        title: 'Ưu đãi chào bạn mới mừng năm 2026',
        discountAmount: 200000,
        minOrderValue: 1000000,
        expiryDate: DateTime.now().add(const Duration(days: 90)),
      ),
      VoucherModel(
        id: 'SUMMER2026',
        title: 'Ưu đãi hè rực rỡ giảm 10% toàn bộ dịch vụ',
        discountPercent: 10,
        minOrderValue: 2000000,
        maxDiscount: 500000,
        expiryDate: DateTime.now().add(const Duration(days: 60)),
      ),
    ];
  }
}
