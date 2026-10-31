import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../../navigation/presentation/screens/main_navigation_shell.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _busy = false, _hidden = true, _agreed = true;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (_busy ||
        auth.isLoading ||
        !_form.currentState!.validate() ||
        !_agreed) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final ok = await auth.register(
        fullName: _name.text,
        phone: _phone.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted || ModalRoute.of(context)?.isCurrent != true || !ok) return;
      // The request has finished. Reading its confirmation is a separate action.
      setState(() => _busy = false);
      if (auth.isAuthenticated && !auth.isGuest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng ký tài khoản thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationShell(enableCommunityTab: true)),
          (_) => false,
        );
      } else if (auth.isEmailConfirmationPending) {
        await showDialog<void>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Kiểm tra email xác nhận'),
            content: const SingleChildScrollView(
              child: Text(
                'Yêu cầu đăng ký đã được tiếp nhận. Nếu nhận được thư xác nhận, hãy mở liên kết trong thư hoặc nhập mã OTP. Bạn chưa đăng nhập vào tài khoản. Kiểm tra cả thư rác.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialog).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OtpVerificationScreen(email: _email.text.trim()),
                    ),
                  );
                },
                child: const Text('Nhập mã OTP'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
    List<String>? hints,
    String? Function(String?)? validator,
    bool password = false,
    bool last = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      key: ValueKey(key),
      controller: controller,
      enabled: !_busy && !context.watch<AuthProvider>().isLoading,
      keyboardType: keyboard,
      autofillHints: hints,
      obscureText: password && _hidden,
      autocorrect: !password,
      enableSuggestions: !password,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: last ? (_) => _submit() : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: password
            ? IconButton(
                tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              )
            : null,
      ),
      validator: validator,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = _busy || auth.isLoading;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo tài khoản')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Lưu những chuyến đi của riêng bạn',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text('Thông tin cá nhân'),
                      const SizedBox(height: 16),
                      _field(
                        'register-name',
                        'Họ và tên',
                        _name,
                        hints: const [AutofillHints.name],
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Vui lòng nhập họ và tên'
                            : null,
                      ),
                      _field(
                        'register-phone',
                        'Số điện thoại',
                        _phone,
                        keyboard: TextInputType.phone,
                        hints: const [AutofillHints.telephoneNumber],
                        validator: (v) => v == null || v.trim().length < 9
                            ? 'Số điện thoại không hợp lệ'
                            : null,
                      ),
                      Text(
                        'Thông tin đăng nhập',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _field(
                        'register-email',
                        'Email',
                        _email,
                        keyboard: TextInputType.emailAddress,
                        hints: const [AutofillHints.email],
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Email không hợp lệ'
                            : null,
                      ),
                      _field(
                        'register-password',
                        'Mật khẩu',
                        _password,
                        password: true,
                        hints: const [AutofillHints.newPassword],
                        validator: (v) => v == null || v.length < 6
                            ? 'Mật khẩu tối thiểu 6 ký tự'
                            : null,
                      ),
                      const Text(
                        'Dùng mật khẩu riêng cho TravelGO, tối thiểu 6 ký tự.',
                      ),
                      const SizedBox(height: 16),
                      _field(
                        'register-confirm',
                        'Xác nhận mật khẩu',
                        _confirm,
                        password: true,
                        last: true,
                        hints: const [AutofillHints.newPassword],
                        validator: (v) => v != _password.text
                            ? 'Mật khẩu xác nhận không khớp'
                            : null,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _agreed,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => _agreed = v ?? false),
                        title: const Text(
                          'Tôi đồng ý với Điều khoản dịch vụ & Chính sách bảo mật của TravelGO.',
                        ),
                      ),
                      if (busy)
                        Semantics(
                          liveRegion: true,
                          child: const Text('Đang gửi yêu cầu đăng ký…'),
                        ),
                      if (!busy && auth.errorMessage != null)
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            auth.errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy || !_agreed ? null : _submit,
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (busy)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            const Text('Đăng ký tài khoản'),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Về màn hình Đăng nhập'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
