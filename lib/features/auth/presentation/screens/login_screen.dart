import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../../../navigation/presentation/screens/main_navigation_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSocialLoading = false;
  bool _showEmailForm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(auth.errorMessage ?? 'Đăng nhập không thành công.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleOAuthLogin(OAuthProvider provider) async {
    final providerName = provider == OAuthProvider.google ? 'Google' : 'Facebook';
    setState(() => _isSocialLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithOAuth(provider);

    if (!mounted) return;
    setState(() => _isSocialLoading = false);

    if (success) {
      if (auth.isAuthenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationShell()),
          (route) => false,
        );
      }
    } else {
      final msg = auth.errorMessage ?? 'Đăng nhập qua $providerName không thành công.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleContinueAsGuest() {
    context.read<AuthProvider>().continueAsGuest();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 24, color: Color(0xFF0F172A)),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              _handleContinueAsGuest();
            }
          },
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Travel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'GO',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF086C61),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            children: [
              // Hero Member Rewards Card (Directly inspired by Trip.com reference)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFE8F5F3),
                      Color(0xFFE0F2FE),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCCECE6)),
                ),
                child: Column(
                  children: [
                    // Graphic Illustration Badge
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.9),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF086C61).withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.flight_takeoff_rounded,
                              size: 40,
                              color: Color(0xFF086C61),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                                SizedBox(width: 4),
                                Text(
                                  'REWARDS',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Rewards Title
                    const Text(
                      'Đăng nhập nhận quyền lợi thành viên',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Benefits row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('🏷️', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 4),
                        Text(
                          'Ưu đãi độc quyền',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        SizedBox(width: 8),
                        Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                        SizedBox(width: 8),
                        Text('🪙', style: TextStyle(fontSize: 13)),
                        SizedBox(width: 4),
                        Text(
                          'Tích điểm mỗi lần đặt',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Animated Switcher: Main SSO Actions VS Direct Email Form
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _showEmailForm ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                // FIRST: Trip.com Style SSO Buttons
                firstChild: Column(
                  children: [
                    // Button 1: Continue with Google
                    _buildSsoButton(
                      label: 'Tiếp tục với Google',
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 30, color: Color(0xFFEA4335)),
                      backgroundColor: Colors.white,
                      textColor: const Color(0xFF0F172A),
                      borderColor: const Color(0xFFCBD5E1),
                      onPressed: () => _handleOAuthLogin(OAuthProvider.google),
                    ),
                    const SizedBox(height: 12),

                    // Button 2: Continue with Facebook
                    _buildSsoButton(
                      label: 'Tiếp tục với Facebook',
                      icon: const Icon(Icons.facebook, size: 22, color: Colors.white),
                      backgroundColor: const Color(0xFF1877F2),
                      textColor: Colors.white,
                      onPressed: () => _handleOAuthLogin(OAuthProvider.facebook),
                    ),
                    const SizedBox(height: 12),

                    // Button 3: Continue with Email
                    _buildSsoButton(
                      label: 'Đăng nhập với Email & Mật khẩu',
                      icon: const Icon(Icons.mail_outline_rounded, size: 20, color: Colors.white),
                      backgroundColor: const Color(0xFF086C61),
                      textColor: Colors.white,
                      onPressed: () {
                        setState(() => _showEmailForm = true);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Button 4: Guest
                    _buildSsoButton(
                      label: 'Tiếp tục với vai trò Khách',
                      icon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF0F172A)),
                      backgroundColor: const Color(0xFFF1F5F9),
                      textColor: const Color(0xFF0F172A),
                      onPressed: _handleContinueAsGuest,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

                // SECOND: Email & Password Form
                secondChild: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() => _showEmailForm = false),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                        label: const Text('Chọn phương thức đăng nhập khác'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF086C61),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 12),

                      AppTextField(
                        controller: _emailController,
                        label: 'Địa chỉ Email',
                        hint: 'name@example.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập email';
                          }
                          if (!val.contains('@')) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      AppTextField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        hint: '••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        validator: (val) {
                          if (val == null || val.length < 6) {
                            return 'Mật khẩu tối thiểu 6 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            );
                          },
                          child: const Text(
                            'Quên mật khẩu?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF086C61),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      AppButton(
                        label: 'Đăng nhập',
                        width: double.infinity,
                        backgroundColor: const Color(0xFF086C61),
                        isLoading: auth.isLoading,
                        onPressed: _handleLogin,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Switch to Register Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Chưa có tài khoản? ',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: const Text(
                      'Đăng ký ngay',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF086C61),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Continue as Guest Option
              TextButton(
                onPressed: _handleContinueAsGuest,
                child: const Text(
                  'Khám phá ngay (Không cần đăng nhập)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Legal Terms Footer
              const Text(
                'Bằng việc tiếp tục, bạn đồng ý với Điều khoản dịch vụ & Chính sách quyền riêng tư của TravelGO.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSsoButton({
    required String label,
    required Widget icon,
    required Color backgroundColor,
    Color textColor = Colors.white,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSocialLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 0,
          side: borderColor != null ? BorderSide(color: borderColor) : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
