import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../trips/services/local_account_lifecycle_service.dart';
import '../models/user_model.dart';

class RecoveryIntentCancelledException implements Exception {
  final String message;
  RecoveryIntentCancelledException([this.message = 'Recovery intent was cancelled.']);
  @override
  String toString() => 'RecoveryIntentCancelledException: $message';
}

class AuthProvider extends ChangeNotifier {
  final SupabaseClient? _injectedClient;
  final Future<String?> Function(String userId)? _trustedRoleFetcher;
  final Future<LocalAccountLifecycleService> Function()? _lifecycleLoader;
  final Session? Function()? _sessionReader;
  final Stream<AuthState>? _authStateChanges;
  final DateTime Function() _clock;
  final Timer Function(Duration, void Function()) _timerFactory;
  final Future<bool> Function(OAuthProvider)? _oauthLauncher;
  StreamSubscription<AuthState>? _authSubscription;
  LocalAccountLifecycleService? _lifecycle;
  Future<LocalAccountLifecycleService>? _loadingLifecycle;
  late final Future<void> _initialization;
  Future<void> _credentialTail = Future.value();
  Future<void> _appTail = Future.value();
  Future<bool>? _logoutFuture;
  bool _initializing = false;
  bool _loggingOut = false;
  bool _logoutRetry = false;
  String? _logoutError;
  bool _disposed = false;
  bool _foreground = true;
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;
  bool _credentialBusy = false;
  bool _refreshQueued = false;
  int _requestGeneration = 0;
  Timer? _refreshTimer;
  _OAuthIntent? _oauth;
  Completer<void>? _foregroundReady;
  final Set<VoidCallback> _invalidators = {};
  VoidCallback? _removeLifecycleConsumer;
  UserEntity? _currentUser;
  bool _isGuest = false;
  bool _userChoseGuest = false;
  bool _travelPreferencesLoading = false;
  bool _travelPreferencesLoaded = false;
  String? _travelPreferencesError;
  bool _isLoading = false;
  bool _isDemoSession = false;
  bool _isRecovering = false;
  bool _recoveryBootstrapBlocked = false;
  String? _currentRecoveryIntentId;
  String? _errorMessage;
  bool _isEmailConfirmationPending = false;
  int _authEpoch = 0;

  UserEntity? get currentUser => _currentUser;
  bool get isGuest => _isGuest;
  bool get isRecovering => _isRecovering;
  bool get recoveryBootstrapBlocked => _recoveryBootstrapBlocked;

  Future<void> resolveRecoveryBootstrap(String? intentId) async {
    _recoveryBootstrapBlocked = false;
    if (intentId != null) {
      _currentRecoveryIntentId = intentId;
      _isRecovering = true;
    }
    notifyListeners();
  }

  bool _recoveryCleanupPending = false;
  String? _recoverySessionIntentId;

  Future<void> beginRecovery(String intentId, {String? verifiedUserId}) async {
    _isRecovering = true;
    _currentRecoveryIntentId = intentId;
    if (verifiedUserId != null && _sdkSession()?.user.id == verifiedUserId) {
      _recoverySessionIntentId = intentId;
    }
    _recoveryCleanupPending = false;
    _requestGeneration++;
    _lifecycle?.invalidateAccountContext();
    onLocalAccountInvalidated();
    notifyListeners();
  }

  Future<void> finishRecovery(String intentId) async {
    if (_currentRecoveryIntentId == intentId ||
        (_currentRecoveryIntentId == null && _isRecovering)) {
      _isRecovering = false;
      _currentRecoveryIntentId = null;
      _recoveryCleanupPending = false;
      notifyListeners();
    }
  }

  void revokeRecoveryAuthority([String? intentId]) {
    if (intentId == null || _currentRecoveryIntentId == intentId) {
      _requestGeneration++;
      _currentRecoveryIntentId = null;
      notifyListeners();
    }
  }

  Future<bool> performRecoverySignOut({
    required String intentId,
    required String? verifiedUserId,
  }) {
    return _enqueueCredential(() async {
      final client = _supabaseClient;
      if (client == null) return true;

      // 1. If an account is already authenticated in AuthProvider,
      // this session belongs to a legitimate user login (User B or new login of User A).
      // Recovery cleanup NEVER owns or logs out an authenticated account.
      if (_currentUser != null) {
        return true;
      }

      // SDK exchange can finish before the ready marker is persisted.
      // The queue records that session owner independently of marker phase.
      final sessionOwner = _recoverySessionIntentId;
      if (sessionOwner != null && sessionOwner != intentId) return true;
      if (verifiedUserId == null && sessionOwner != intentId) {
        return true;
      }

      // 3. Inspect current SDK session
      final session = _sdkSession();
      if (session == null) {
        if (_recoverySessionIntentId == intentId) _recoverySessionIntentId = null;
        return true;
      }

      // 4. If the SDK session does not match verifiedUserId,
      // it does not belong to this recovery operation.
      if (verifiedUserId != null && session.user.id != verifiedUserId) {
        return true;
      }

      // 5. If another recovery intent is currently active in AuthProvider,
      // this session belongs to that newer recovery operation!
      // An old/cancelled recovery intent NEVER owns or signs out a newer recovery session.
      if (sessionOwner == null && _isRecovering &&
          _currentRecoveryIntentId != null &&
          _currentRecoveryIntentId != intentId) {
        return true;
      }

      // 6. Clean up the recovery session
      try {
        await client.auth.signOut(scope: SignOutScope.local);
        if (_recoverySessionIntentId == intentId) _recoverySessionIntentId = null;
        return true;
      } catch (_) {
        return false;
      }
    });
  }

  bool isCurrentRecoveryIntent(String intentId) =>
      _isRecovering && _currentRecoveryIntentId == intentId;

  final List<Future<void> Function()> _recoveryInvalidators = [];
  final List<void Function(bool success)> _recoveryCleanupResultListeners = [];

  VoidCallback registerRecoveryInvalidator(Future<void> Function() invalidate) {
    _recoveryInvalidators.add(invalidate);
    return () => _recoveryInvalidators.remove(invalidate);
  }

  VoidCallback registerRecoveryCleanupResultListener(
      void Function(bool success) listener) {
    _recoveryCleanupResultListeners.add(listener);
    return () => _recoveryCleanupResultListeners.remove(listener);
  }

  void _handleRecoveryCancellation() {
    if (_isRecovering || _currentRecoveryIntentId != null) {
      revokeRecoveryAuthority();
      _isRecovering = false;
      _recoveryCleanupPending = true;
      notifyListeners();
      unawaited(_drainAndCleanupRecovery().catchError((_) => false));
    }
  }

  Future<bool> _drainAndCleanupRecovery() async {
    revokeRecoveryAuthority();
    _recoveryCleanupPending = true;
    bool invalidatorsSuccess = true;
    for (final inv in List.of(_recoveryInvalidators)) {
      try {
        await inv();
      } catch (_) {
        invalidatorsSuccess = false;
      }
    }

    bool signOutSuccess = true;
    final client = _supabaseClient;
    if (client != null) {
      await _enqueueCredential(() async {
        try {
          // Do not sign out if a new authenticated user was already established
          if (_currentUser == null) {
            await client.auth.signOut(scope: SignOutScope.local);
          }
        } catch (_) {
          signOutSuccess = false;
        }
      });
    }

    final totalSuccess = invalidatorsSuccess && signOutSuccess;
    for (final cb in List.of(_recoveryCleanupResultListeners)) {
      try {
        cb(totalSuccess);
      } catch (_) {}
    }

    if (totalSuccess) {
      _isRecovering = false;
      _currentRecoveryIntentId = null;
      _recoveryCleanupPending = false;
      notifyListeners();
      return true;
    } else {
      _recoveryCleanupPending = true;
      notifyListeners();
      return false;
    }
  }

  Future<void> cancelRecovery(String intentId) async {
    if (_currentRecoveryIntentId == intentId ||
        (_currentRecoveryIntentId == null && _isRecovering)) {
      await _drainAndCleanupRecovery();
    }
  }

  Future<T> runRecoveryMutation<T>(
    String intentId,
    Future<T> Function(SupabaseClient) action,
  ) {
    if (_disposed) throw StateError('AuthProvider is disposed');
    if (!isCurrentRecoveryIntent(intentId)) {
      throw RecoveryIntentCancelledException();
    }
    final client = _supabaseClient;
    if (client == null) throw StateError('SDK client unavailable');
    final capturedGeneration = _requestGeneration;
    return _enqueueCredential(() async {
      if (_disposed ||
          capturedGeneration != _requestGeneration ||
          !isCurrentRecoveryIntent(intentId)) {
        throw RecoveryIntentCancelledException();
      }
      _credentialBusy = true;
      try {
        final result = await action(client);
        if (_disposed ||
            capturedGeneration != _requestGeneration ||
            !isCurrentRecoveryIntent(intentId)) {
          try {
            await client.auth.signOut(scope: SignOutScope.local);
          } catch (_) {}
          throw RecoveryIntentCancelledException();
        }
        if (result is AuthSessionUrlResponse) {
          _recoverySessionIntentId = intentId;
        }
        return result;
      } finally {
        _credentialBusy = false;
      }
    });
  }
  bool get travelPreferencesLoading => _travelPreferencesLoading;
  bool get travelPreferencesLoaded => _travelPreferencesLoaded;
  String? get travelPreferencesError => _travelPreferencesError;
  bool get isLoading => _isLoading;
  bool get isDemoSession => _isDemoSession;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailConfirmationPending => _isEmailConfirmationPending;
  int get authEpoch => _authEpoch;
  Future<void> get initialization => _initialization;
  bool get isInitializing => _initializing;
  bool get isLoggingOut => _loggingOut;
  bool get logoutNeedsRetry => _logoutRetry;
  String? get logoutErrorMessage => _logoutError;

  AuthProvider({
    SupabaseClient? client,
    this._trustedRoleFetcher,
    this._lifecycleLoader,
    this._sessionReader,
    this._authStateChanges,
    DateTime Function()? clock,
    Timer Function(Duration, void Function())? timerFactory,
    this._oauthLauncher,
    this._recoveryBootstrapBlocked = false,
    String? initialRecoveryIntentId,
  }) : _injectedClient = client,
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _timerFactory = timerFactory ?? Timer.new,
       _currentRecoveryIntentId = initialRecoveryIntentId,
       _isRecovering = initialRecoveryIntentId != null {
    _initialization = _lifecycleLoader == null
        ? Future.sync(_initSession)
        : _initializeGuarded();
  }

  SupabaseClient? get _supabaseClient {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _initSession() {
    if (_recoveryBootstrapBlocked || _isRecovering || _currentRecoveryIntentId != null) return;
    final client = _supabaseClient;
    if (client == null) return;

    final session = client.auth.currentSession;
    if (session != null) {
      _authEpoch++;
      _currentUser = _mapSupabaseUser(session.user);
      _isGuest = false;
      _isDemoSession = false;
      _fetchTrustedRole(session.user.id, _authEpoch);
    }

    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      if (_disposed || _recoveryBootstrapBlocked || _isRecovering || _currentRecoveryIntentId != null) return;
      if (data.event == AuthChangeEvent.passwordRecovery) return;
      if (_userChoseGuest) {
        _currentUser = null;
        _isGuest = true;
        _isDemoSession = false;
        _isLoading = false;
        notifyListeners();
        return;
      }
      final session = data.session;
      _authEpoch++;
      if (session != null) {
        _currentUser = _mapSupabaseUser(session.user);
        _isGuest = false;
        _isDemoSession = false;
        _isLoading = false;
        _errorMessage = null;
        _fetchTrustedRole(session.user.id, _authEpoch);
      } else {
        _currentUser = null;
        _isGuest = true;
        _isDemoSession = false;
        _isLoading = false;
        _errorMessage = null;
      }
      notifyListeners();
    });
  }

  UserEntity _mapSupabaseUser(
    User user, {
    String? fallbackName,
    String? fallbackPhone,
  }) {
    final meta = user.userMetadata ?? {};
    final fullName =
        (meta['full_name'] as String?)?.trim() ??
        fallbackName?.trim() ??
        (user.email != null && user.email!.contains('@')
            ? user.email!.split('@').first
            : 'Thành viên TravelGO');

    final phone =
        (meta['phone'] as String?)?.trim() ??
        fallbackPhone?.trim() ??
        (user.phone ?? '');

    // SECURITY: Client-supplied userMetadata is untrusted for privileged roles.
    // Real Supabase users are ALWAYS mapped to customer by default until verified
    // by trusted server source (e.g. public.profiles via _fetchTrustedRole).
    return UserEntity(
      id: user.id,
      fullName: fullName,
      email: user.email ?? '',
      phone: phone,
      role: UserRole.customer,
      avatarUrl: meta['avatar_url'] as String?,
      address: (meta['address'] as String?) ?? 'Việt Nam',
    );
  }

  Future<void> _fetchTrustedRole(String userId, int epoch) async {
    try {
      String? roleStr;
      final fetcher = _trustedRoleFetcher;
      if (fetcher != null) {
        roleStr = await fetcher(userId);
        if (_authEpoch != epoch || _currentUser?.id != userId) {
          return;
        }
        if (roleStr != null) {
          final newRole = roleStr == 'admin'
              ? UserRole.admin
              : UserRole.customer;

          if (_currentUser != null && _currentUser!.role != newRole) {
            _currentUser = _currentUser!.copyWith(role: newRole);
            notifyListeners();
          }
        }
      } else {
        final client = _supabaseClient;
        if (client != null) {
          final res = await client
              .from('profiles')
              .select('role, full_name, phone, avatar_url, address')
              .eq('id', userId)
              .maybeSingle();

          if (_authEpoch != epoch || _currentUser?.id != userId) {
            return; // Stale response ignored
          }

          if (res != null) {
            if (res['role'] != null) {
              roleStr = res['role'] as String?;
            }
            final serverName = (res['full_name'] as String?)?.trim();
            final serverPhone = (res['phone'] as String?)?.trim();
            final serverAvatar = res['avatar_url'] as String?;
            final serverAddress = (res['address'] as String?)?.trim();

            final current = _currentUser;
            if (current != null) {
              final newRole = roleStr != null
                  ? (roleStr == 'admin'
                        ? UserRole.admin
                        : UserRole.customer)
                  : current.role;

              _currentUser = current.copyWith(
                fullName: (serverName != null && serverName.isNotEmpty)
                    ? serverName
                    : current.fullName,
                phone: (serverPhone != null && serverPhone.isNotEmpty)
                    ? serverPhone
                    : current.phone,
                avatarUrl: serverAvatar ?? current.avatarUrl,
                address: (serverAddress != null && serverAddress.isNotEmpty)
                    ? serverAddress
                    : current.address,
                role: newRole,
              );
              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      // Safe error handling: failure never elevates privileges or breaks the session
      debugPrint('Notice: Unable to fetch trusted role: $e');
    }
  }

  void continueAsGuest() {
    _handleRecoveryCancellation();
    _userChoseGuest = true;
    _travelPreferencesLoaded = false;
    _travelPreferencesLoading = false;
    _travelPreferencesError = null;
    _errorMessage = null;
    _isLoading = false;
    if (_lifecycleLoader != null) {
      _requestGeneration++;
      _isGuest = true;
      _currentUser = null;
      _cancelOAuth();
      _lifecycle?.invalidateAccountContext();
      onLocalAccountInvalidated();
      notifyListeners();
      return;
    }
    _currentUser = null;
    _isGuest = true;
    _isDemoSession = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Real Supabase Email & Password Login without any mock bypasses
  Future<bool> login(String email, String password) async {
    if (_isRecovering || _currentRecoveryIntentId != null || _recoveryCleanupPending) {
      final cleaned = await _drainAndCleanupRecovery();
      if (!cleaned) {
        _errorMessage = 'Không thể đăng nhập do phiên khôi phục mật khẩu trước đó chưa hoàn tất dọn dẹp.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    }
    _userChoseGuest = false;
    if (_lifecycleLoader != null) {
      return _guardedMutation(
        (client) => client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        ),
      );
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    return _enqueueCredential(() async {
      final client = _supabaseClient;
      if (client == null) {
        _errorMessage = 'Chưa thể kết nối tới cơ sở dữ liệu Supabase. Vui lòng kiểm tra kết nối mạng.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      try {
        final response = await client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );

        if (response.user != null) {
          _authEpoch++;
          _currentUser = _mapSupabaseUser(response.user!);
          _isGuest = false;
          _isDemoSession = false;
          _isLoading = false;
          notifyListeners();
          _fetchTrustedRole(response.user!.id, _authEpoch);
          return true;
        } else {
          _errorMessage = 'Không nhận được dữ liệu phiên đăng nhập từ máy chủ.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      } on AuthException catch (e) {
        _errorMessage = _translateAuthError(e.message);
        _isLoading = false;
        notifyListeners();
        return false;
      } catch (e) {
        _errorMessage = 'Lỗi kết nối máy chủ Supabase: ${e.toString()}';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    });
  }

  /// Real Supabase OAuth Sign-In (Google & Facebook)
  Future<bool> signInWithOAuth(OAuthProvider provider) async {
    if (_isRecovering || _currentRecoveryIntentId != null || _recoveryCleanupPending) {
      final cleaned = await _drainAndCleanupRecovery();
      if (!cleaned) return false;
    }
    _userChoseGuest = false;
    if (_lifecycleLoader != null) return _guardedOAuth(provider);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final client = _supabaseClient;
    final providerName = provider == OAuthProvider.google
        ? 'Google'
        : 'Facebook';
    if (client == null) {
      _errorMessage = 'Chưa thể kết nối tới cơ sở dữ liệu Supabase.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final success = await client.auth.signInWithOAuth(
        provider,
        redirectTo: 'io.supabase.travelgo://login-callback',
      );
      _isLoading = false;
      notifyListeners();
      return success;
    } on AuthException catch (e) {
      _isLoading = false;
      final lower = e.message.toLowerCase();
      if (lower.contains('not enabled') ||
          lower.contains('disabled') ||
          lower.contains('unsupported')) {
        _errorMessage =
            'Nhà cung cấp $providerName chưa được kích hoạt trên Supabase Dashboard. Vui lòng sử dụng đăng nhập Email/Mật khẩu thật.';
      } else {
        _errorMessage = _translateAuthError(e.message);
      }
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      final lower = e.toString().toLowerCase();
      if (lower.contains('not enabled') ||
          lower.contains('disabled') ||
          lower.contains('unsupported')) {
        _errorMessage =
            'Nhà cung cấp $providerName chưa được kích hoạt trên Supabase Dashboard. Vui lòng sử dụng đăng nhập Email/Mật khẩu thật.';
      } else {
        _errorMessage =
            'Không thể kết nối dịch vụ $providerName: ${e.toString()}';
      }
      notifyListeners();
      return false;
    }
  }

  /// Helper retained strictly for unit test fixtures
  @visibleForTesting
  Future<void> quickDemoLogin(UserRole role) async {
    _handleRecoveryCancellation();
    _requestGeneration++;
    _authEpoch++;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 100));
    if (_disposed) return;

    switch (role) {
      case UserRole.customer:
        _currentUser = UserEntity.demoMinh();
        break;
      case UserRole.admin:
        _currentUser = UserEntity.demoAdmin();
        break;
    }

    _isGuest = false;
    _isDemoSession =
        true; // Demo identity has local provenance and no live credentials
    _isLoading = false;
    notifyListeners();
  }

  /// Helper retained strictly for security & unit test suites
  @visibleForTesting
  void simulateSupabaseUser(
    User user, {
    String? fallbackName,
    String? fallbackPhone,
  }) {
    _requestGeneration++;
    _authEpoch++;
    _currentUser = _mapSupabaseUser(
      user,
      fallbackName: fallbackName,
      fallbackPhone: fallbackPhone,
    );
    _isGuest = false;
    _isDemoSession = false;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
    _fetchTrustedRole(user.id, _authEpoch);
  }

  /// Real Supabase User Registration into PostgreSQL auth.users
  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    if (_isRecovering || _currentRecoveryIntentId != null || _recoveryCleanupPending) {
      final cleaned = await _drainAndCleanupRecovery();
      if (!cleaned) return false;
    }
    _userChoseGuest = false;
    if (_lifecycleLoader != null) {
      return _guardedMutation(
        (client) => client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'full_name': fullName.trim(), 'phone': phone.trim()},
        ),
        allowConfirmation: true,
      );
    }
    _isLoading = true;
    _errorMessage = null;
    _isEmailConfirmationPending = false;
    notifyListeners();

    final client = _supabaseClient;
    if (client == null) {
      _errorMessage = 'Chưa thể kết nối tới cơ sở dữ liệu Supabase. Vui lòng kiểm tra kết nối mạng.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
          'role': 'customer',
        },
      );

      if (response.user != null) {
        if (response.session != null) {
          _authEpoch++;
          _currentUser = _mapSupabaseUser(
            response.user!,
            fallbackName: fullName,
            fallbackPhone: phone,
          );
          _isGuest = false;
          _isDemoSession = false;
          _isEmailConfirmationPending = false;
          _fetchTrustedRole(response.user!.id, _authEpoch);
        } else {
          // Supabase mailer_autoconfirm is false: confirmation email was dispatched
          _isEmailConfirmationPending = true;
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Không thể tạo tài khoản trên máy chủ Supabase.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on AuthException catch (e) {
      _errorMessage = _translateAuthError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Lỗi kết nối máy chủ Supabase: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// OTP verification via Supabase verifyOTP
  Future<bool> verifyOtp(String code, {String? email}) async {
    if (_isRecovering || _currentRecoveryIntentId != null || _recoveryCleanupPending) {
      final cleaned = await _drainAndCleanupRecovery();
      if (!cleaned) return false;
    }
    final trimmedCode = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmedCode)) {
      _errorMessage = 'Mã xác thực phải gồm đúng 6 chữ số.';
      notifyListeners();
      return false;
    }

    final targetEmail = (email != null && email.trim().isNotEmpty)
        ? email.trim()
        : _currentUser?.email.trim();
    if (targetEmail == null || targetEmail.isEmpty || !targetEmail.contains('@')) {
      _errorMessage = 'Thiếu thông tin email để xác thực OTP.';
      notifyListeners();
      return false;
    }

    if (_lifecycleLoader != null) {
      return _guardedMutation(
        (client) => client.auth.verifyOTP(
          email: targetEmail,
          token: trimmedCode,
          type: OtpType.signup,
        ),
      );
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final client = _supabaseClient;
    if (client == null) {
      _errorMessage = 'Chưa thể kết nối tới cơ sở dữ liệu Supabase. Vui lòng kiểm tra kết nối mạng.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    try {
      final res = await client.auth.verifyOTP(
        email: targetEmail,
        token: trimmedCode,
        type: OtpType.signup,
      );

      final currentSession = _sdkSession() ?? client.auth.currentSession;
      if (res.user != null &&
          res.session != null &&
          !res.session!.isExpired &&
          currentSession != null &&
          !currentSession.isExpired &&
          currentSession.user.id == res.user!.id &&
          res.session!.user.id == res.user!.id) {
        _authEpoch++;
        _currentUser = _mapSupabaseUser(res.user!);
        _isGuest = false;
        _isDemoSession = false;
        _isLoading = false;
        notifyListeners();
        _fetchTrustedRole(res.user!.id, _authEpoch);
        return true;
      } else {
        _errorMessage = 'Xác thực OTP không thành công hoặc phiên đăng nhập không khả dụng.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on AuthException catch (e) {
      _errorMessage = _translateAuthError(e.message);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Lỗi xác thực mã OTP: Không thể hoàn tất yêu cầu.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loadTravelPreferences({bool force = false}) async {
    final user = _currentUser;
    if (user == null || _isGuest) {
      _travelPreferencesLoading = false;
      _travelPreferencesLoaded = false;
      return false;
    }
    if (_travelPreferencesLoaded && !force) return true;

    final client = _supabaseClient;
    if (client == null) {
      _travelPreferencesError = 'Chưa thể kết nối tới máy chủ.';
      notifyListeners();
      return false;
    }

    final requestEpoch = _authEpoch;
    final requestUserId = user.id;
    bool isCurrentSession() =>
        _authEpoch == requestEpoch && _currentUser?.id == requestUserId;

    _travelPreferencesLoading = true;
    _travelPreferencesError = null;
    notifyListeners();

    try {
      final res = await client
          .from('profiles')
          .select('id, interests, typical_budget_vnd, travel_style')
          .eq('id', user.id);

      if (!isCurrentSession()) return false;

      if (res.isNotEmpty) {
        final first = res.first;
        if (first['id'] == user.id) {
          final prefs = TravelPreferences.fromJson(first);
          _currentUser = _currentUser?.copyWith(travelPreferences: prefs);
          _travelPreferencesLoaded = true;
          _travelPreferencesLoading = false;
          notifyListeners();
          return true;
        }
      }
      _travelPreferencesLoaded = false;
      _travelPreferencesLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      if (isCurrentSession()) {
        _travelPreferencesError = 'Không thể tải sở thích du lịch.';
        _travelPreferencesLoading = false;
        _travelPreferencesLoaded = false;
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> updateTravelPreferences(TravelPreferences preferences) async {
    final user = _currentUser;
    if (user == null || _isGuest || !_travelPreferencesLoaded) return false;

    final client = _supabaseClient;
    if (client == null) {
      _travelPreferencesError = 'Chưa thể kết nối tới máy chủ.';
      notifyListeners();
      return false;
    }

    final requestEpoch = _authEpoch;
    final requestUserId = user.id;
    bool isCurrentSession() =>
        _authEpoch == requestEpoch && _currentUser?.id == requestUserId;

    _travelPreferencesLoading = true;
    _travelPreferencesError = null;
    notifyListeners();

    try {
      final res = await client
          .from('profiles')
          .update(preferences.toJson())
          .eq('id', user.id)
          .select('id, interests, typical_budget_vnd, travel_style')
          .maybeSingle();

      if (!isCurrentSession()) return false;

      if (res == null || res['id'] != user.id) {
        _travelPreferencesError = 'Không thể cập nhật sở thích du lịch.';
        _travelPreferencesLoading = false;
        notifyListeners();
        return false;
      }

      final updated = TravelPreferences.fromJson(res);
      _currentUser = _currentUser?.copyWith(travelPreferences: updated);
      _travelPreferencesLoading = false;
      _travelPreferencesLoaded = true;
      notifyListeners();
      return true;
    } catch (_) {
      if (isCurrentSession()) {
        _travelPreferencesError = 'Lỗi cập nhật sở thích: không thể hoàn tất.';
        _travelPreferencesLoading = false;
        notifyListeners();
      }
      return false;
    }
  }

  /// Update user profile in Supabase public.profiles table.
  /// Strict least-privilege: payload ONLY contains allowed columns (full_name, phone, avatar_url, address).
  /// Never sends id, email, role in the update payload.
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? address,
  }) async {
    final user = _currentUser;
    if (user == null) {
      _errorMessage = 'Bạn chưa đăng nhập.';
      notifyListeners();
      return false;
    }

    if (_isDemoSession) {
      // Demo session local update
      _currentUser = user.copyWith(
        fullName: fullName != null && fullName.trim().isNotEmpty
            ? fullName.trim()
            : user.fullName,
        phone: phone != null && phone.trim().isNotEmpty
            ? phone.trim()
            : user.phone,
        avatarUrl: avatarUrl ?? user.avatarUrl,
        address: address != null && address.trim().isNotEmpty
            ? address.trim()
            : user.address,
      );
      notifyListeners();
      return true;
    }

    final client = _supabaseClient;
    if (client == null) {
      _errorMessage = 'Chưa thể kết nối tới cơ sở dữ liệu Supabase.';
      notifyListeners();
      return false;
    }

    final requestEpoch = _authEpoch;
    final requestUserId = user.id;

    bool isCurrentSession() =>
        _authEpoch == requestEpoch && _currentUser?.id == requestUserId;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Build safe payload strictly restricted to permitted column grants
      final Map<String, dynamic> payload = {};
      if (fullName != null) payload['full_name'] = fullName.trim();
      if (phone != null) payload['phone'] = phone.trim();
      if (avatarUrl != null) payload['avatar_url'] = avatarUrl.trim();
      if (address != null) payload['address'] = address.trim();

      if (payload.isEmpty) {
        if (isCurrentSession()) {
          _isLoading = false;
          notifyListeners();
        }
        return true;
      }

      // UI-01: Acknowledge mutation directly on the update statement itself.
      // Do NOT execute an independent GET / select to infer update success.
      final res = await client
          .from('profiles')
          .update(payload)
          .eq('id', user.id)
          .select('id, full_name, phone, avatar_url, address, role')
          .maybeSingle();

      if (!isCurrentSession()) {
        // Session changed during update - do not modify new session state
        return false;
      }

      // UI-01: Must have a valid returned row with matching user ID from the mutation itself
      if (res == null || res['id'] != user.id) {
        _isLoading = false;
        _errorMessage =
            'Không thể xác thực bản ghi hồ sơ đã cập nhật từ máy chủ';
        notifyListeners();
        return false;
      }

      _currentUser = _currentUser?.copyWith(
        fullName: res['full_name'] as String? ?? _currentUser?.fullName,
        phone: res['phone'] as String? ?? _currentUser?.phone,
        avatarUrl: res['avatar_url'] as String? ?? _currentUser?.avatarUrl,
        address: res['address'] as String? ?? _currentUser?.address,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on PostgrestException catch (e) {
      if (!isCurrentSession()) {
        return false;
      }
      _isLoading = false;
      _errorMessage = 'Lỗi cập nhật hồ sơ: ${e.message}';
      notifyListeners();
      return false;
    } catch (e) {
      if (!isCurrentSession()) {
        return false;
      }
      _isLoading = false;
      _errorMessage = 'Lỗi không xác định khi cập nhật hồ sơ: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> logout() {
    _handleRecoveryCancellation();
    if (_lifecycleLoader != null) return _guardedLogout();
    _authEpoch++;
    _currentUser = null;
    _isGuest = true;
    _isDemoSession = false;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();

    final client = _supabaseClient;
    if (client != null) {
      return client.auth.signOut().then((_) => true, onError: (_) => false);
    }
    return Future.value(true);
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  void _notifyDeferred() {
    if (_disposed) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      scheduleMicrotask(notifyListeners);
    }
  }

  void onLocalAccountInvalidated() {
    final guestAvailable = _userChoseGuest ||
        (!_isRecovering &&
            _currentRecoveryIntentId == null &&
            (_isGuest || _currentUser != null || _loggingOut));
    _authEpoch++;
    _currentUser = null;
    _isGuest = guestAvailable;
    _isDemoSession = false;
    _refreshTimer?.cancel();
    for (final invalidate in List<VoidCallback>.of(_invalidators)) {
      invalidate();
    }
    _notifyDeferred();
  }

  VoidCallback registerAccountInvalidator(VoidCallback invalidate) {
    _invalidators.add(invalidate);
    return () => _invalidators.remove(invalidate);
  }

  Future<T> _enqueueCredential<T>(Future<T> Function() action) {
    final completion = Completer<T>();
    _credentialTail = _credentialTail.then((_) async {
      try {
        completion.complete(await action());
      } catch (e, st) {
        completion.completeError(e, st);
      }
    });
    return completion.future;
  }

  Session? _sdkSession() {
    try {
      return _sessionReader != null
          ? _sessionReader()
          : _supabaseClient?.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  Future<LocalAccountLifecycleService> _getLifecycle() =>
      _loadingLifecycle ??= _loadLifecycle();
  Future<LocalAccountLifecycleService> _loadLifecycle() async {
    final service = await _lifecycleLoader!();
    _lifecycle = service;
    if (_disposed) throw StateError('Auth closed.');
    _removeLifecycleConsumer = service.registerConsumer(
      invalidate: onLocalAccountInvalidated,
      bind: (_) async {},
    );
    return service;
  }

  Future<void> _initializeGuarded() {
    _initializing = true;
    _authSubscription =
        (_authStateChanges ?? _supabaseClient?.auth.onAuthStateChange)?.listen(
          _observeSdk,
          onError: (_) {
            if (!_credentialBusy && !_disposed) {
              _errorMessage = 'Không thể kiểm tra phiên đăng nhập.';
              _denyObservedSession();
            }
          },
        );
    final generation = _requestGeneration;
    return _enqueueCredential(() async {
      try {
        if (_recoveryBootstrapBlocked || _isRecovering) return;
        final service = await _getLifecycle();
        if (_disposed || generation != _requestGeneration) return;
        await _awaitForeground();
        if (_disposed || generation != _requestGeneration) return;
        await service.resumeAccount();
        _publish(generation);
      } catch (_) {
        if (!_disposed && generation == _requestGeneration) {
          onLocalAccountInvalidated();
          _errorMessage =
              'Chưa thể kiểm tra dữ liệu tài khoản; bạn vẫn có thể dùng Guest.';
        }
      } finally {
        _initializing = false;
        _notifyDeferred();
      }
    });
  }

  void _observeSdk(AuthState event) {
    if (_disposed || _initializing || _credentialBusy || _loggingOut || _isRecovering || _currentRecoveryIntentId != null) return;
    if (event.event == AuthChangeEvent.passwordRecovery) return;
    if (_userChoseGuest) return;
    final session = event.session;
    final current = _sdkSession();
    if (session != null &&
        current != null &&
        session.user.id == _currentUser?.id &&
        session.accessToken == current.accessToken &&
        _lifecycle?.handle != null) {
      if (event.event == AuthChangeEvent.userUpdated) {
        final previousRole = _currentUser!.role;
        _currentUser = _mapSupabaseUser(session.user)
            .copyWith(role: previousRole);
        _notifyDeferred();
      }
      return;
    }
    if (session == null && _currentUser == null) return;
    _denyObservedSession();
  }

  void _denyObservedSession() {
    _requestGeneration++;
    _cancelOAuth();
    _lifecycle?.invalidateAccountContext();
    onLocalAccountInvalidated();
    unawaited(
      _enqueueCredential(() async {
        if (_disposed) return;
        try {
          await (await _getLifecycle()).revokeAccount();
        } catch (_) {
          _errorMessage = 'Cần kiểm tra lại phiên và dọn dữ liệu tài khoản.';
        }
        _notifyDeferred();
      }),
    );
  }

  bool _publish(int generation) {
    if (_disposed ||
        !_foreground ||
        generation != _requestGeneration ||
        _loggingOut ||
        _logoutRetry ||
        _isRecovering ||
        _currentRecoveryIntentId != null) {
      return false;
    }
    final service = _lifecycle;
    final session = _sdkSession();
    final handle = service?.handle;
    if (handle == null ||
        session == null ||
        handle.ownerId != session.user.id) {
      return false;
    }
    final proof = service!.captureProof();
    if (!service.isCurrentProof(proof) ||
        proof.accessToken != session.accessToken) {
      return false;
    }
    _authEpoch++;
    _currentUser = _mapSupabaseUser(session.user);
    _isGuest = false;
    _isDemoSession = false;
    _errorMessage = null;
    _fetchTrustedRole(session.user.id, _authEpoch);
    _scheduleRefresh();
    _notifyDeferred();
    return true;
  }

  void _scheduleRefresh({bool retry = false}) {
    _refreshTimer?.cancel();
    final session = _sdkSession();
    final expires = session?.expiresAt;
    if (!_foreground || expires == null || _currentUser == null || _disposed) {
      return;
    }
    final remaining = expires * 1000 - _clock().millisecondsSinceEpoch;
    if (remaining <= 10000) return;
    final delay = retry ? 30000 : (remaining - 60000).clamp(0, remaining);
    _refreshTimer = _timerFactory(Duration(milliseconds: delay), () {
      if (!_disposed && _foreground) unawaited(refreshSessionIfNeeded());
    });
  }

  Future<void> _awaitForeground() async {
    if (!_foreground && !_disposed) {
      _foregroundReady ??= Completer<void>();
      await _foregroundReady!.future;
    }
  }

  Future<bool> _guardedMutation(
    Future<AuthResponse> Function(SupabaseClient) sdk, {
    bool allowConfirmation = false,
  }) {
    if (_disposed || _logoutRetry) return Future.value(false);
    _cancelOAuth();
    final generation = ++_requestGeneration;
    _lifecycle?.invalidateAccountContext();
    onLocalAccountInvalidated();
    _isLoading = true;
    _errorMessage = null;
    _notifyDeferred();
    return _enqueueCredential(() async {
      LocalAccountLifecycleService? service;
      var dispatched = false;
      _credentialBusy = true;
      try {
        if (_disposed || generation != _requestGeneration || _logoutRetry) {
          return false;
        }
        final client = _supabaseClient;
        if (client == null) throw StateError('SDK unavailable.');
        service = await _getLifecycle();
        await service.prepareAuthenticationMutation();
        if (_disposed || generation != _requestGeneration) return false;
        dispatched = true;
        final sdkWatch = Stopwatch()..start();
        final response = await sdk(client);
        sdkWatch.stop();
        debugPrint('[TravelGO auth] authentication_sdk ${sdkWatch.elapsedMilliseconds}ms');
        if (_disposed || generation != _requestGeneration) {
          await client.auth.signOut(scope: SignOutScope.local);
          return false;
        }
        service.completeAuthenticationMutation();
        if (allowConfirmation &&
            response.session == null &&
            response.user != null) {
          _isEmailConfirmationPending = true;
          return true;
        }
        _isEmailConfirmationPending = false;
        if (response.session == null ||
            response.session!.isExpired ||
            response.user == null ||
            _sdkSession()?.user.id != response.user!.id ||
            _sdkSession()?.isExpired == true) {
          return false;
        }
        await _awaitForeground();
        if (_disposed || generation != _requestGeneration) {
          await client.auth.signOut(scope: SignOutScope.local);
          return false;
        }
        final authWatch = Stopwatch()..start();
        await service.establishAccount(freshAuthentication: true);
        authWatch.stop();
        debugPrint('[TravelGO auth] account_authorize ${authWatch.elapsedMilliseconds}ms');
        return _publish(generation);
      } catch (_) {
        if (!_disposed && generation == _requestGeneration) {
          _errorMessage = dispatched
              ? 'Không thể hoàn tất xác thực tài khoản.'
              : 'Chưa thể chuẩn bị phiên an toàn; vui lòng thử lại.';
        }
        return false;
      } finally {
        service?.completeAuthenticationMutation();
        _credentialBusy = false;
        if (generation == _requestGeneration) _isLoading = false;
        _notifyDeferred();
      }
    });
  }

  Future<bool> _guardedLogout() {
    final existing = _logoutFuture;
    if (existing != null) return existing;
    _requestGeneration++;
    _cancelOAuth();
    _foregroundReady?.complete();
    _foregroundReady = null;
    _lifecycle?.invalidateAccountContext();
    onLocalAccountInvalidated();
    _loggingOut = true;
    _logoutError = null;
    _notifyDeferred();
    final operation = _enqueueCredential(() async {
      LocalAccountLifecycleService? service;
      var localClean = false;
      var sdkClean = false;
      _credentialBusy = true;
      try {
        service = await _getLifecycle();
        await service.prepareAuthenticationMutation();
        localClean = await service.revokeAccount();
        final client = _supabaseClient;
        if (client != null) {
          try {
            await client.auth.signOut(scope: SignOutScope.local);
            sdkClean = true;
          } catch (_) {
            sdkClean = false;
          }
        } else {
          sdkClean = _sdkSession() == null;
        }
      } catch (_) {
        localClean = false;
      } finally {
        service?.completeAuthenticationMutation();
        _credentialBusy = false;
      }
      final success = localClean && sdkClean;
      _logoutRetry = !success;
      _logoutError = success
          ? null
          : !localClean
          ? 'Chưa dọn xong dữ liệu tài khoản trên máy. Vui lòng thử hoàn tất đăng xuất.'
          : 'Đã khóa dữ liệu trên máy nhưng chưa hoàn tất thông báo đăng xuất. Vui lòng thử lại.';
      _loggingOut = false;
      _isLoading = false;
      _logoutFuture = null;
      _notifyDeferred();
      return success;
    });
    _logoutFuture = operation;
    return operation;
  }

  Future<bool> refreshSessionIfNeeded() {
    if (_disposed ||
        !_foreground ||
        _credentialBusy ||
        _loggingOut ||
        _refreshQueued ||
        _logoutRetry ||
        _lifecycle?.handle == null) {
      return Future.value(false);
    }
    _refreshQueued = true;
    final generation = _requestGeneration;
    return _enqueueCredential(() async {
      if (_disposed || !_foreground || generation != _requestGeneration) {
        return false;
      }
      _credentialBusy = true;
      final service = _lifecycle!;
      var sdkSucceeded = false;
      final oldExpiry = _sdkSession()?.expiresAt;
      try {
        await service.prepareSessionRefresh();
        try {
          await _supabaseClient!.auth.refreshSession();
          sdkSucceeded = true;
        } catch (_) {
          sdkSucceeded = false;
        }
        await service.completeSessionRefresh(sdkSucceeded: sdkSucceeded);
        final published = _publish(generation);
        if (published &&
            (!sdkSucceeded || _sdkSession()?.expiresAt == oldExpiry)) {
          _scheduleRefresh(retry: true);
        }
        return published;
      } catch (_) {
        _errorMessage = 'Chưa thể làm mới phiên đăng nhập.';
        return false;
      } finally {
        _credentialBusy = false;
        _notifyDeferred();
      }
    }).whenComplete(() => _refreshQueued = false);
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) {
    if (_disposed || _lifecycleLoader == null) return Future.value();
    if (state == _lastLifecycleState) return _appTail;
    _lastLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _foregroundReady?.complete();
      _foregroundReady = null;
    } else {
      _foreground = false;
      _refreshTimer?.cancel();
      if (state == AppLifecycleState.detached) {
        _lifecycle?.invalidateAccountContext();
      } else if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden) {
        unawaited(_lifecycle?.suspendForegroundContext() ?? Future.value());
      }
      onLocalAccountInvalidated();
    }
    final result = Completer<void>();
    _appTail = _appTail.then((_) async {
      try {
        if (_disposed) return;
        final service = await _getLifecycle();
        if (state == AppLifecycleState.paused) {
          await service.sealForPause();
        } else if (state == AppLifecycleState.resumed &&
            _foreground &&
            !_userChoseGuest &&
            !_credentialBusy &&
            !_loggingOut &&
            !_initializing &&
            !_isRecovering &&
            _currentRecoveryIntentId == null) {
          await service.resumeForegroundContext();
          _publish(_requestGeneration);
        }
      } catch (_) {
        _errorMessage =
            'Cần kiểm tra lại phiên trước khi mở dữ liệu tài khoản.';
      } finally {
        result.complete();
        _notifyDeferred();
      }
    });
    return result.future;
  }

  void _cancelOAuth() {
    _foregroundReady?.complete();
    _foregroundReady = null;
    final intent = _oauth;
    if (intent == null) return;
    intent.canceled = true;
    intent.timeout?.cancel();
    if (!intent.callback.isCompleted) intent.callback.complete(null);
    if (!intent.result.isCompleted) intent.result.complete(false);
    _oauth = null;
    _isLoading = false;
  }

  bool acceptsAuthCallback(Uri uri) {
    final intent = _oauth;
    if (intent == null ||
        intent.canceled ||
        intent.claimed ||
        _disposed ||
        _loggingOut ||
        intent.generation != _requestGeneration) {
      return false;
    }
    return uri.scheme == 'io.supabase.travelgo' &&
        uri.host == 'login-callback' &&
        uri.path.isEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasFragment &&
        ((uri.queryParametersAll['code']?.length == 1 &&
                (uri.queryParameters['code']?.trim().isNotEmpty ?? false)) ||
            uri.queryParameters.containsKey('error')) &&
        !uri.queryParameters.keys.any((key) => key.contains('token'));
  }

  Future<bool> handleAuthCallback(Uri uri) {
    if (!acceptsAuthCallback(uri)) return Future.value(false);
    final intent = _oauth!;
    intent.claimed = true;
    intent.callback.complete(uri);
    return intent.result.future;
  }

  Future<bool> _guardedOAuth(OAuthProvider provider) {
    if (_disposed || _logoutRetry || _oauth != null) return Future.value(false);
    final generation = ++_requestGeneration;
    final intent = _OAuthIntent(generation);
    _oauth = intent;
    _lifecycle?.invalidateAccountContext();
    _isLoading = true;
    onLocalAccountInvalidated();
    intent.timeout = _timerFactory(const Duration(seconds: 120), () {
      if (identical(_oauth, intent)) {
        _requestGeneration++;
        _cancelOAuth();
        _notifyDeferred();
      }
    });
    unawaited(
      _enqueueCredential(() async {
        LocalAccountLifecycleService? service;
        _credentialBusy = true;
        var exchanged = false;
        try {
          final client = _supabaseClient;
          if (client == null || intent.canceled || _disposed) return;
          service = await _getLifecycle();
          await service.prepareAuthenticationMutation();
          if (intent.canceled || _disposed) return;
          final launched = _oauthLauncher != null
              ? await _oauthLauncher(provider)
              : await client.auth.signInWithOAuth(
                  provider,
                  redirectTo: 'io.supabase.travelgo://login-callback',
                );
          if (!launched || intent.canceled) return;
          final uri = await intent.callback.future;
          if (uri == null ||
              intent.canceled ||
              _disposed ||
              uri.queryParameters.containsKey('error')) {
            return;
          }
          // Continuation of this credential job, not a second queued job.
          exchanged = true;
          final response = await client.auth.exchangeCodeForSession(
            uri.queryParameters['code']!,
          );
          if (intent.canceled ||
              generation != _requestGeneration ||
              _disposed) {
            await client.auth.signOut(scope: SignOutScope.local);
            return;
          }
          service.completeAuthenticationMutation();
          await _awaitForeground();
          if (intent.canceled ||
              generation != _requestGeneration ||
              _disposed ||
              _sdkSession()?.user.id != response.session.user.id) {
            await client.auth.signOut(scope: SignOutScope.local);
            return;
          }
          await service.establishAccount(freshAuthentication: true);
          if (!intent.result.isCompleted) {
            intent.result.complete(_publish(generation));
          }
        } catch (_) {
          if (!_disposed) {
            _errorMessage = 'Không thể hoàn tất đăng nhập qua nhà cung cấp.';
          }
          if (exchanged && intent.canceled) {
            try {
              await _supabaseClient?.auth.signOut(scope: SignOutScope.local);
            } catch (_) {
              _logoutRetry = true;
              _logoutError = 'Cần hoàn tất đăng xuất phiên đã hủy.';
            }
          }
        } finally {
          service?.completeAuthenticationMutation();
          intent.timeout?.cancel();
          if (!intent.result.isCompleted) intent.result.complete(false);
          if (identical(_oauth, intent)) _oauth = null;
          _credentialBusy = false;
          if (generation == _requestGeneration) _isLoading = false;
          _notifyDeferred();
        }
      }),
    );
    return intent.result.future;
  }

  Future<void> close() {
    dispose();
    return Future.wait([_credentialTail, _appTail]).then((_) {});
  }

  @override
  void dispose() {
    if (_disposed) return;
    _requestGeneration++;
    _cancelOAuth();
    _refreshTimer?.cancel();
    _lifecycle?.invalidateAccountContext();
    onLocalAccountInvalidated();
    _disposed = true;
    unawaited(_authSubscription?.cancel() ?? Future.value());
    _removeLifecycleConsumer?.call();
    _invalidators.clear();
    super.dispose();
  }

  String _translateAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Email hoặc mật khẩu không chính xác.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already registered')) {
      return 'Email này đã được đăng ký tài khoản. Vui lòng đăng nhập.';
    }
    if (lower.contains('password should be at least')) {
      return 'Mật khẩu phải chứa ít nhất 6 ký tự.';
    }
    if (lower.contains('invalid email') || lower.contains('email provider')) {
      return 'Địa chỉ email không hợp lệ.';
    }
    if (lower.contains('rate limit')) {
      return 'Bạn thao tác quá nhanh. Vui lòng đợi trong giây lát rồi thử lại.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email chưa được xác thực. Vui lòng kiểm tra hộp thư email hoặc tắt tính năng "Confirm email" trên Supabase Dashboard.';
    }
    if (lower.contains('not enabled') ||
        lower.contains('provider is not enabled')) {
      return 'Nhà cung cấp đăng nhập này chưa được kích hoạt trên Supabase Dashboard.';
    }
    return message;
  }
}

final class _OAuthIntent {
  final int generation;
  final callback = Completer<Uri?>();
  final result = Completer<bool>();
  bool canceled = false;
  bool claimed = false;
  Timer? timeout;
  _OAuthIntent(this.generation);
}
