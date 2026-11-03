import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

/// Nút Avatar Cá nhân / Cài đặt dùng chung trên AppBar mọi màn hình
class GlobalProfileAvatarAction extends StatelessWidget {
  const GlobalProfileAvatarAction({super.key});

  @override
  Widget build(BuildContext context) {
    AuthProvider? auth;
    try {
      auth = Provider.of<AuthProvider>(context, listen: true);
    } on ProviderNotFoundException catch (_) {
      auth = null;
    }
    final user = auth?.currentUser;
    final isGuest = auth == null || auth.isGuest || user == null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isGuest) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          ),
          icon: const Icon(Icons.person_outline, size: 20),
          label: const Text('Đăng nhập', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(40, 36),
          ),
        ),
      );
    }

    final initial = user.fullName.trim().isNotEmpty
        ? user.fullName.trim().substring(0, 1).toUpperCase()
        : 'U';

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: 'Trang cá nhân: ${user.fullName}',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const CustomerProfileScreen(),
            ),
          ),
          child: CircleAvatar(
            radius: 17,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
