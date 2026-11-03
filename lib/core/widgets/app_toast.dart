import 'package:flutter/material.dart';

/// Tiện ích hiển thị thông báo nổi xúc giác (Floating Toast / SnackBar)
class AppToast {
  static void showSuccess(BuildContext context, String message) {
    _showToast(
      context,
      message,
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF10B981), // Emerald green
    );
  }

  static void showError(BuildContext context, String message) {
    _showToast(
      context,
      message,
      icon: Icons.error_outline_rounded,
      backgroundColor: const Color(0xFFEF4444), // Rose red
    );
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(
      context,
      message,
      icon: Icons.info_outline_rounded,
      backgroundColor: const Color(0xFF3B82F6), // Blue
    );
  }

  static void _showToast(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color backgroundColor,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: backgroundColor,
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
