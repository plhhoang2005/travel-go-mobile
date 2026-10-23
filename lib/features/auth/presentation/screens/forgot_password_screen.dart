import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/password_recovery_state.dart';
import '../../providers/password_recovery_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final recovery = context.read<PasswordRecoveryProvider>();
    await recovery.requestEmail(_emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    final recovery = context.watch<PasswordRecoveryProvider>();
    final isSending = recovery.state == RecoveryState.sending;
    final isEmailRequested = recovery.state == RecoveryState.emailRequested;

    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.lock_reset,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Khôi phục mật khẩu',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    if (isEmailRequested) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.green[700]),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Yêu cầu đã được tiếp nhận',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              recovery.successMessage ??
                                  'Nếu email phù hợp trong hệ thống, bạn sẽ nhận được đường dẫn đặt lại mật khẩu.',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const Text(
                        'Nhập email tài khoản của bạn để nhận đường dẫn đặt lại mật khẩu.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('recovery-email-field'),
                        controller: _emailController,
                        enabled: !isSending,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email tài khoản',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty || !v.contains('@')) {
                            return 'Vui lòng nhập email hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      if (recovery.errorMessage != null) ...[
                        Text(
                          recovery.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        key: const ValueKey('request-recovery-btn'),
                        onPressed: isSending ? null : _submit,
                        child: isSending
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Gửi hướng dẫn đặt lại mật khẩu'),
                      ),
                      const SizedBox(height: 12),
                    ],
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
    );
  }
}
