import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../providers/auth_provider.dart';
import '../../../navigation/presentation/screens/main_navigation_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _agreedToTerms = true;
  String _passwordStrength = '';
  Color _passwordStrengthColor = Colors.grey;
  double _passwordStrengthPercent = 0.0;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _calculatePasswordStrength(String pass) {
    if (pass.isEmpty) {
      setState(() {
        _passwordStrength = '';
        _passwordStrengthPercent = 0.0;
        _passwordStrengthColor = Colors.grey;
      });
      return;
    }

    if (pass.length < 6) {
      setState(() {
        _passwordStrength = 'Yếu (Tối thiểu 6 ký tự)';
        _passwordStrengthPercent = 0.33;
        _passwordStrengthColor = const Color(0xFFEF4444);
      });
    } else if (pass.length >= 8 && RegExp(r'[0-9]').hasMatch(pass)) {
      setState(() {
        _passwordStrength = 'Mạnh (Bảo mật cao)';
        _passwordStrengthPercent = 1.0;
        _passwordStrengthColor = const Color(0xFF10B981);
      });
    } else {
      setState(() {
        _passwordStrength = 'Trung bình (Nên thêm số hoặc ký tự)';
        _passwordStrengthPercent = 0.66;
        _passwordStrengthColor = const Color(0xFFF59E0B);
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với Điều khoản sử dụng của TravelGO'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      fullName: _nameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(auth.errorMessage ?? 'Đăng ký thất bại. Vui lòng thử lại.'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng ký và kích hoạt tài khoản thành công!'),
          backgroundColor: Color(0xFF086C61),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationShell()),
        (route) => false,
      );
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.mark_email_read_rounded, color: Color(0xFF086C61), size: 26),
              SizedBox(width: 8),
              Text('Đăng ký thành công', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tài khoản đã được tạo thành công trên cơ sở dữ liệu Supabase!',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 14),
              ),
              const SizedBox(height: 10),
              Text(
                'Một thư xác thực đã được gửi tới:\n${_emailController.text}\n\nVui lòng kiểm tra hòm thư và nhấn vào liên kết kích hoạt trước khi đăng nhập.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '💡 Mẹo quản trị: Để đăng ký không cần mở email, hãy gạt Tắt mục "Confirm email" tại Supabase Dashboard -> Authentication -> Providers -> Email.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Về màn hình Đăng nhập',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF086C61)),
              ),
            ),
          ],
        ),
      );
    }
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Incentive Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE8F5F3),
                        Color(0xFFE0F2FE),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCCECE6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🎁', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Đăng ký thành viên TravelGO',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Nhận ngay voucher 200.000₫ & tích điểm TravelPoint',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF086C61),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Form Fields
                AppTextField(
                  controller: _nameController,
                  label: 'Họ và tên',
                  hint: 'Nguyễn Văn A',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
                ),
                const SizedBox(height: 14),

                AppTextField(
                  controller: _phoneController,
                  label: 'Số điện thoại',
                  hint: '0901234567',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (val) =>
                      val == null || val.trim().length < 9 ? 'Số điện thoại không hợp lệ' : null,
                ),
                const SizedBox(height: 14),

                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'example@travelgo.vn',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) {
                    if (val == null || !val.contains('@')) {
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
                  onChanged: _calculatePasswordStrength,
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Mật khẩu tối thiểu 6 ký tự';
                    }
                    return null;
                  },
                ),

                // Password strength bar
                if (_passwordStrength.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _passwordStrengthPercent,
                            backgroundColor: const Color(0xFFE2E8F0),
                            color: _passwordStrengthColor,
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _passwordStrength,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _passwordStrengthColor,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                AppTextField(
                  controller: _confirmPasswordController,
                  label: 'Xác nhận mật khẩu',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (val) {
                    if (val != _passwordController.text) {
                      return 'Mật khẩu xác nhận không khớp';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Terms Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        activeColor: const Color(0xFF086C61),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                            children: [
                              TextSpan(text: 'Tôi đồng ý với '),
                              TextSpan(
                                text: 'Điều khoản dịch vụ & Chính sách bảo mật',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF086C61),
                                ),
                              ),
                              TextSpan(text: ' của TravelGO.'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button
                AppButton(
                  label: 'Đăng ký tài khoản',
                  width: double.infinity,
                  backgroundColor: const Color(0xFF086C61),
                  isLoading: auth.isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 24),

                // Back to Login Prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Đã có tài khoản? ',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Đăng nhập ngay',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF086C61),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
