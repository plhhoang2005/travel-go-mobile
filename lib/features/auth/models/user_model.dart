enum UserRole {
  customer,
  partner,
  admin,
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Khách hàng';
      case UserRole.partner:
        return 'Đối tác Cung ứng';
      case UserRole.admin:
        return 'Quản trị viên';
    }
  }

  String get badgeName {
    switch (this) {
      case UserRole.customer:
        return 'CUSTOMER';
      case UserRole.partner:
        return 'PARTNER';
      case UserRole.admin:
        return 'ADMIN';
    }
  }
}

class UserEntity {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final String? address;

  const UserEntity({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.address,
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

  factory UserEntity.demoPartner() {
    return const UserEntity(
      id: 'ptn-furama-01',
      fullName: 'Resort Furama Đà Nẵng',
      email: 'partner@furama.vn',
      phone: '02363847333',
      role: UserRole.partner,
      address: 'Võ Nguyên Giáp, Ngũ Hành Sơn, Đà Nẵng',
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
  }) {
    return UserEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      address: address ?? this.address,
    );
  }
}
