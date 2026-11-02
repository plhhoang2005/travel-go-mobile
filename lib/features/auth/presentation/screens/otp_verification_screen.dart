import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../../navigation/presentation/screens/main_navigation_shell.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final bool isResetPassword;
  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.isResetPassword = false,
  });
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final auth = context.read<AuthProvider>();
    final trimmedEmail = widget.email.trim();
    if (widget.isResetPassword ||
        _busy ||
        auth.isLoading ||
        trimmedEmail.isEmpty ||
        !trimmedEmail.contains('@') ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final ok = await auth.verifyOtp(_code.text, email: widget.email);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (ok && auth.isAuthenticated && !auth.isGuest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Xác thực email thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationShell(enableCommunityTab: true)),
          (_) => false,
        );
      } else if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Mã xác thực không hợp lệ hoặc đã hết hạn.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = _busy || auth.isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận email')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.mark_email_read_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.isResetPassword
                          ? 'Khôi phục mật khẩu chưa khả dụng'
                          : 'Nhập mã từ email của bạn',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    if (widget.isResetPassword)
                      const Text(
                        'Màn hình này không thể đặt lại mật khẩu. Chưa có yêu cầu khôi phục nào được gửi.',
                      )
                    else ...[
                      Text(
                        'Chỉ dùng mã đăng ký nhận được tại ${widget.email}. Màn hình này không gửi hoặc gửi lại email.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('otp-code'),
                        controller: _code,
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _verify(),
                        decoration: const InputDecoration(
                          labelText: 'Mã xác nhận 6 chữ số',
                        ),
                        validator: (v) =>
                            (v == null || !RegExp(r'^\d{6}$').hasMatch(v.trim()))
                                ? 'Nhập đủ 6 chữ số'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      if (busy)
                        Semantics(
                          liveRegion: true,
                          child: const Text('Đang xác nhận mã…'),
                        ),
                      if (!busy && auth.errorMessage != null)
                        Text(
                          auth.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      FilledButton(
                        onPressed: busy ? null : _verify,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.center,
                          children: [
                            if (busy)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            const Text('Xác nhận email'),
                          ],
                        ),
                      ),
                    ],
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Quay lại'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
