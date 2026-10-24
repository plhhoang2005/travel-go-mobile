enum UserRole { customer, admin }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Khách hàng';
      case UserRole.admin:
        return 'Quản trị viên';
    }
  }

  String get badgeName {
    switch (this) {
      case UserRole.customer:
        return 'CUSTOMER';
      case UserRole.admin:
        return 'ADMIN';
    }
  }
}

/// Private, optional travel settings. These never grant roles or mutate trips.
class TravelPreferences {
  static const maxBudgetVnd = 9007199254740991;
  static const maxInterests = 20;
  static const maxTextLength = 80;
  final List<String> interests;
  final int? typicalBudgetVnd;
  final String? travelStyle;
  TravelPreferences._(
    List<String> interests,
    this.typicalBudgetVnd,
    this.travelStyle,
  ) : interests = List.unmodifiable(interests);

  factory TravelPreferences.fromInput({
    List<String> interests = const [],
    int? typicalBudgetVnd,
    String? travelStyle,
  }) {
    final style = travelStyle?.trim();
    return TravelPreferences.fromJson({
      'interests': interests.map((s) => s.trim()).toList(),
      'typical_budget_vnd': typicalBudgetVnd,
      'travel_style': style == null || style.isEmpty ? null : style,
    });
  }
  factory TravelPreferences.fromJson(Map<String, Object?> json) {
    bool text(Object? value) =>
        value is String &&
        value.isNotEmpty &&
        value == value.trim() &&
        value.runes.length <= maxTextLength &&
        !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value);
    final interests = json['interests'];
    final budget = json['typical_budget_vnd'];
    final style = json['travel_style'];
    if (!json.containsKey('typical_budget_vnd') ||
        !json.containsKey('travel_style') ||
        interests is! List ||
        interests.length > maxInterests ||
        !interests.every(text) ||
        interests.toSet().length != interests.length ||
        (budget != null &&
            (budget is! int || budget < 0 || budget > maxBudgetVnd)) ||
        (style != null && !text(style))) {
      throw const FormatException('invalid_travel_preferences');
    }
    return TravelPreferences._(
      List<String>.from(interests),
      budget as int?,
      style as String?,
    );
  }
  Map<String, Object?> toJson() => {
    'interests': interests,
    'typical_budget_vnd': typicalBudgetVnd,
    'travel_style': travelStyle,
  };
}

class UserEntity {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final String? address;
  final TravelPreferences? travelPreferences;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.address,
    this.travelPreferences,
  });

  factory UserEntity.demoMinh() {
    return const UserEntity(
      id: 'usr-minh-01',
      fullName: 'Hoàng Minh',
      email: 'minh@travelgo.vn',
      phone: '0901234567',
      role: UserRole.customer,
      address: 'Quận 1, TP. Hồ Chí Minh',
    );
  }

  factory UserEntity.demoAdmin() {
    return const UserEntity(
      id: 'adm-root-01',
      fullName: 'Quản Trị TravelGO',
      email: 'admin@travelgo.vn',
      phone: '0988888888',
      role: UserRole.admin,
      address: 'Tòa nhà TravelGO, Cầu Giấy, Hà Nội',
    );
  }

  UserEntity copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    String? avatarUrl,
    String? address,
    TravelPreferences? travelPreferences,
  }) {
    return UserEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      address: address ?? this.address,
      travelPreferences: travelPreferences ?? this.travelPreferences,
    );
  }
}
