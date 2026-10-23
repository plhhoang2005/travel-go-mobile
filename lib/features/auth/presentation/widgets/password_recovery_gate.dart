import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        if (recovery.isReady || recovery.isCleanupRequired) {
          return const ResetPasswordScreen();
        }
        return child;
      },
    );
  }
}
