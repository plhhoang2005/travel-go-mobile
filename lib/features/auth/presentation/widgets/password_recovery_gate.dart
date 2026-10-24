import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/password_recovery_state.dart';
import '../../providers/password_recovery_provider.dart';
import '../screens/reset_password_screen.dart';

class PasswordRecoveryGate extends StatelessWidget {
  final Widget child;

  const PasswordRecoveryGate({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PasswordRecoveryProvider>(
      builder: (context, recovery, _) {
        final state = recovery.state;
        final phase = recovery.currentIntent?.phase;

        // 1. While exchanging callback link: show dedicated exchange loading screen
        if (state == RecoveryState.exchanging) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang xác thực liên kết khôi phục...'),
                ],
              ),
            ),
          );
        }

        // 2. Error during callback without ready authority
        if (state == RecoveryState.error && phase != RecoveryPhase.ready) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Lỗi xác thực'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => recovery.cancel(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      recovery.errorMessage ??
                          'Liên kết khôi phục không hợp lệ hoặc đã hết hạn.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => recovery.cancel(),
                      child: const Text('Quay lại đăng nhập'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 3. Keep ResetPasswordScreen mounted across:
        // ready, updating, cleanupRequired, uncertain,
        // and error when phase is ready (e.g. server rejection on submit)
        final shouldShowResetScreen = recovery.isReady ||
            recovery.isCleanupRequired ||
            state == RecoveryState.updating ||
            state == RecoveryState.uncertain ||
            (state == RecoveryState.error && phase == RecoveryPhase.ready);

        if (shouldShowResetScreen) {
          return const ResetPasswordScreen();
        }

        return child;
      },
    );
  }
}
