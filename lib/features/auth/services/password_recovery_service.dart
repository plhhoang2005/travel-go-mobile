import 'package:supabase_flutter/supabase_flutter.dart';

class PasswordRecoveryService {
  static const String defaultRedirectUrl =
      'io.supabase.travelgo://login-callback?flow=recovery';

  Future<void> requestEmail(
    SupabaseClient client,
    String email, {
    String redirectTo = defaultRedirectUrl,
  }) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw const FormatException('Email không hợp lệ.');
    }
    await client.auth.resetPasswordForEmail(
      trimmed,
      redirectTo: redirectTo,
    );
  }

  Future<AuthSessionUrlResponse> exchange(
    SupabaseClient client,
    String code,
  ) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Mã xác thực không hợp lệ.');
    }
    final response = await client.auth.exchangeCodeForSession(trimmed);
    final redirectType = response.redirectType?.toLowerCase();
    final isValidType = redirectType == 'passwordrecovery' ||
        redirectType == 'recovery';
    if (!isValidType || response.session.isExpired) {
      throw const AuthException('Phản hồi khôi phục mật khẩu không hợp lệ.');
    }
    return response;
  }

  Future<UserResponse> updatePassword(
    SupabaseClient client,
    String password,
  ) async {
    final trimmed = password.trim();
    if (trimmed.length < 8) {
      throw const FormatException('Mật khẩu mới phải có tối thiểu 8 ký tự.');
    }
    return client.auth.updateUser(
      UserAttributes(password: trimmed),
    );
  }
}
