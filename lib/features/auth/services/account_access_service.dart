import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Immutable model representing verified account access and role status.
class AccountAccess {
  final String subjectId;
  final String role;
  final int revision;
  final String state;
  final bool sessionValid;

  const AccountAccess({
    required this.subjectId,
    required this.role,
    required this.revision,
    required this.state,
    required this.sessionValid,
  });

  bool get isEnabled => state == 'enabled' && sessionValid;
  bool get isLocked => state == 'locked';
  bool get isAdmin => role == 'admin';

  factory AccountAccess.fromJson(Map<String, dynamic> json) {
    return AccountAccess(
      subjectId: json['subjectId'] as String? ?? json['subject_id'] as String? ?? '',
      role: json['role'] as String? ?? 'customer',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      state: json['state'] as String? ?? 'enabled',
      sessionValid: json['sessionValid'] as bool? ?? json['session_valid'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'role': role,
    'revision': revision,
    'state': state,
    'sessionValid': sessionValid,
  };
}

/// Typed exception for account access denials.
class AccountAccessDenied implements Exception {
  final String code;
  final String? message;

  const AccountAccessDenied(this.code, [this.message]);

  @override
  String toString() => 'AccountAccessDenied($code${message != null ? ': $message' : ''})';
}

/// Service that verifies caller account state and session validity via Supabase RPC.
class AccountAccessService {
  final SupabaseClient? client;
  final Future<Map<String, dynamic>> Function(String token)? injectedVerifier;

  AccountAccessService({
    this.client,
    this.injectedVerifier,
  });

  /// Verifies own account access using current_account_access RPC.
  /// Throws [AccountAccessDenied] if account is locked, unauthorized, or invalid.
  Future<AccountAccess> verify(String token) async {
    if (token.trim().isEmpty) {
      throw const AccountAccessDenied('unauthorized', 'Missing or empty session token.');
    }

    if (injectedVerifier != null) {
      try {
        final raw = await injectedVerifier!(token);
        final access = AccountAccess.fromJson(raw);
        if (access.isLocked) {
          throw const AccountAccessDenied('account_locked', 'Account is locked by administrator.');
        }
        if (!access.sessionValid) {
          throw const AccountAccessDenied('invalid_session', 'Session is invalid or expired.');
        }
        return access;
      } on AccountAccessDenied {
        rethrow;
      } catch (e) {
        if (e is AccountAccessDenied) rethrow;
        throw AccountAccessDenied('verification_failed', e.toString());
      }
    }

    final supabaseClient = client ?? Supabase.instance.client;

    try {
      final res = await supabaseClient.rpc('current_account_access');
      if (res == null) {
        throw const AccountAccessDenied('missing_access', 'No access data returned from server.');
      }

      final Map<String, dynamic> map = res is Map<String, dynamic>
          ? res
          : Map<String, dynamic>.from(res as Map);

      final access = AccountAccess.fromJson(map);

      if (access.isLocked) {
        throw const AccountAccessDenied('account_locked', 'Account is locked by administrator.');
      }
      if (!access.sessionValid) {
        throw const AccountAccessDenied('invalid_session', 'Session is invalid or expired.');
      }

      return access;
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.message.contains('unauthorized')) {
        throw AccountAccessDenied('unauthorized', e.message);
      }
      if (e.message.contains('account_locked')) {
        throw AccountAccessDenied('account_locked', e.message);
      }
      throw AccountAccessDenied(e.code ?? 'rpc_error', e.message);
    } catch (e) {
      if (e is AccountAccessDenied) rethrow;
      throw AccountAccessDenied('transport_error', e.toString());
    }
  }
}
