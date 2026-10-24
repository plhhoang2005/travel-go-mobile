import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/presentation/travel_image.dart';
import '../../../../core/presentation/travel_media.dart';
import '../../providers/auth_provider.dart';
import '../../../navigation/presentation/screens/main_navigation_shell.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _slow = false, _hidden = true;
  int _operation = 0;
  String? _action;
  Timer? _timer;

  @override
  void dispose() {
    _operation++;
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _openHome() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const MainNavigationShell()),
    (_) => false,
  );

  void _guest() {
    _operation++;
    _timer?.cancel();
    context.read<AuthProvider>().continueAsGuest();
    _openHome();
  }

  Future<void> _submit({OAuthProvider? provider}) async {
    final auth = context.read<AuthProvider>();
    if (_busy || auth.isLoading) return;
    if (provider == null && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _slow = false;
      _action = provider == null ? 'đăng nhập' : 'kết nối tài khoản';
    });
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted && operation == _operation) setState(() => _slow = true);
    });
    try {
      final success = provider == null
          ? await auth.login(_email.text, _password.text)
          : await auth.signInWithOAuth(provider);
      if (!mounted || operation != _operation) return;
      if (success &&
          auth.isAuthenticated &&
          !auth.isGuest &&
          ModalRoute.of(context)?.isCurrent == true) {
        _openHome();
      }
    } finally {
      if (mounted && operation == _operation) {
        _timer?.cancel();
        setState(() {
          _busy = false;
          _slow = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final busy = _busy || auth.isLoading;
    final theme = Theme.of(context);
    final compact =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        MediaQuery.textScalerOf(context).scale(16) > 24;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TravelGO'),
        leading: IconButton(
          tooltip: 'Tiếp tục với vai trò Khách',
          onPressed: _guest,
          icon: const Icon(Icons.close),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: TextButton(
            onPressed: _guest,
            child: const Text('Tiếp tục với vai trò Khách'),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!compact) ...[
                        TravelImage(
                          media: TravelMediaCatalog.forDestination('ha-noi'),
                          semanticLabel: 'Hồ Hoàn Kiếm, Hà Nội',
                          height: 160,
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        'Chuyến đi tiếp theo bắt đầu từ đây',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Đăng nhập để lưu và mở lại chuyến đi của bạn trên tài khoản.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('login-email'),
                        controller: _email,
                        enabled: !busy,
                        autofillHints: const [AutofillHints.username],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: const InputDecoration(
                          labelText: 'Địa chỉ Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) => v == null || !v.trim().contains('@')
                            ? 'Vui lòng nhập email hợp lệ'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('login-password'),
                        controller: _password,
                        enabled: !busy,
                        obscureText: _hidden,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                            onPressed: () => setState(() => _hidden = !_hidden),
                            icon: Icon(
                              _hidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 6
                            ? 'Mật khẩu tối thiểu 6 ký tự'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                ),
                          child: const Text('Quên mật khẩu?'),
                        ),
                      ),
                      if (busy)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _slow
                                  ? 'Đang chờ xác thực. Bạn có thể tiếp tục với Khách; yêu cầu cũ sẽ không mở lại tài khoản.'
                                  : 'Đang $_action…',
                            ),
                          ),
                        ),
                      if (!busy && auth.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              auth.errorMessage!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      FilledButton(
                        key: const ValueKey('login-submit'),
                        onPressed: busy ? null : () => _submit(),
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
                            const Text('Đăng nhập'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _submit(provider: OAuthProvider.google),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Tiếp tục với Google'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _submit(provider: OAuthProvider.facebook),
                        icon: const Icon(Icons.facebook),
                        label: const Text('Tiếp tục với Facebook'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                        child: const Text('Chưa có tài khoản? Đăng ký ngay'),
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
