import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final isGuest = auth.isGuest || user == null;

    final displayName = isGuest ? 'Khách Vãng Lai' : user.fullName;
    final email = isGuest ? 'Chưa đăng nhập tài khoản' : user.email;
    final roleName = isGuest ? 'GUEST' : user.role.badgeName;
    final roleColor = isGuest
        ? AppTheme.slate500
        : (user.role == UserRole.admin
            ? const Color(0xFFEF4444)
            : (user.role == UserRole.partner ? const Color(0xFF0D9488) : const Color(0xFF0284C7)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // User Header Card
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF0F172A),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.slate900),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                roleName,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 13, color: AppTheme.slate500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Guest Login Promotion Banner
            if (isGuest)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8F5F3), Color(0xFFE0F2FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCCECE6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 36, color: Color(0xFF086C61)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Bạn đang dùng tài khoản Khách',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Đăng nhập tài khoản thật để đồng bộ lịch trình',
                            style: TextStyle(fontSize: 11, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF086C61),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text('Đăng nhập', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Menu Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildMenuItem(Icons.person_outline, 'Thông tin cá nhân', () {}),
                    _buildDivider(),
                    _buildMenuItem(Icons.people_outline, 'Danh bạ người đi cùng (Travelers)', () {}),
                    _buildDivider(),
                    _buildMenuItem(Icons.confirmation_number_outlined, 'Kho mã giảm giá & Voucher', () {}),
                    _buildDivider(),
                    _buildMenuItem(Icons.currency_exchange, 'Tiền tệ & Ngôn ngữ', () {}, trailing: 'VND · Tiếng Việt'),
                    _buildDivider(),
                    _buildMenuItem(
                      Icons.dns_outlined,
                      'Máy chủ Backend (API)',
                      () => _showBackendConfigDialog(context),
                      trailing: ApiConstants.baseUrl.split('/api')[0],
                    ),
                    _buildDivider(),
                    _buildMenuItem(Icons.security_outlined, 'Bảo mật & Điều khoản', () {}),
                    _buildDivider(),
                    _buildMenuItem(Icons.help_outline, 'Trợ giúp & Liên hệ hỗ trợ', () {}),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Logout / Login Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: isGuest
                    ? FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        icon: const Icon(Icons.login, size: 18),
                        label: const Text('Đăng nhập / Đăng ký ngay'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () {
                          auth.logout();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã đăng xuất tài khoản')),
                          );
                        },
                        icon: const Icon(Icons.logout, size: 18, color: Color(0xFFEF4444)),
                        label: const Text(
                          'Đăng xuất',
                          style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {String? trailing}) {
    return ListTile(
      leading: Icon(icon, size: 20, color: AppTheme.slate700),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.slate800)),
      trailing: trailing != null
          ? Text(trailing, style: const TextStyle(fontSize: 12, color: AppTheme.slate500))
          : const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.slate400),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9));
  }

  void _showBackendConfigDialog(BuildContext context) {
    final controller = TextEditingController(text: ApiConstants.overrideBaseUrl ?? ApiConstants.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cấu hình Máy chủ Backend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập URL Backend API (Hữu ích khi test trên thiết bị thật qua mạng Wi-Fi LAN hoặc máy chủ từ xa):',
              style: TextStyle(fontSize: 13, color: AppTheme.slate600, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'http://192.168.1.x:8080/api/v1',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ApiConstants.overrideBaseUrl = null;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã khôi phục URL API mặc định')),
              );
            },
            child: const Text('Mặc định'),
          ),
          FilledButton(
            onPressed: () {
              ApiConstants.overrideBaseUrl = controller.text.trim();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã lưu URL API: ${ApiConstants.baseUrl}')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF086C61)),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}
