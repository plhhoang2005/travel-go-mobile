import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/password_recovery_state.dart';
import '../services/password_recovery_service.dart';
import '../services/recovery_intent_store.dart';
import 'auth_provider.dart';

class _RecoveryPreflightFailure implements Exception {
  final String message;
  final bool retryable;

  const _RecoveryPreflightFailure(this.message, {this.retryable = false});
}

class PasswordRecoveryProvider extends ChangeNotifier {
  final PasswordRecoveryService service;
  final RecoveryIntentStore store;
  final AuthProvider auth;
  final SupabaseClient? Function()? clientProvider;
  final DateTime Function() _clock;

  RecoveryState _state = RecoveryState.idle;
  PendingRecovery? _currentIntent;
  PendingRecovery? _cleanupIntent;
  Future<void> _markerTail = Future<void>.value();
  int? _invalidatedGeneration;
  bool _authCleanupPending = false;
  String? _errorMessage;
  String? _successMessage;
  Future<void>? _initFuture;
  Future<bool>? _inFlightExchange;
  String? _activeExchangeCode;
  int _generation = 0;
  Object? _submitOwner;

  VoidCallback? _removeRecoveryInvalidator;
  VoidCallback? _removeRecoveryCleanupResultListener;

  PasswordRecoveryProvider({
    required this.service,
    required this.store,
    required this.auth,
    this.clientProvider,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()) {
    _removeRecoveryInvalidator = auth.registerRecoveryInvalidator(
      _handleRecoveryInvalidated,
    );
    _removeRecoveryCleanupResultListener = auth
        .registerRecoveryCleanupResultListener(_handleRecoveryCleanupResult);
  }

  void _handleRecoveryCleanupResult(bool success) {
    _authCleanupPending = false;
    if (_invalidatedGeneration != _generation) return;
    if (!success) {
      _state = RecoveryState.cleanupRequired;
      _errorMessage =
          'Chưa thể hoàn tất dọn dẹp phiên khôi phục. Vui lòng thử lại.';
      notifyListeners();
    } else {
      _currentIntent = null;
      _cleanupIntent = null;
      _state = RecoveryState.idle;
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<void> _handleRecoveryInvalidated() async {
    final intent = _currentIntent ?? _cleanupIntent;
    _cleanupIntent = intent;
    _currentIntent = null;
    _generation++;
    _invalidatedGeneration = _generation;
    _submitOwner = null;
    _authCleanupPending = true;
    _initFuture = null;
    _inFlightExchange = null;
    _activeExchangeCode = null;

    bool clearSuccess = true;
    try {
      await _clearMarker(intent?.intentId, generation: _generation);
    } catch (_) {
      clearSuccess = false;
    }

    if (clearSuccess) {
      _state = RecoveryState.idle;
      _errorMessage = null;
      _successMessage = null;
    } else {
      _state = RecoveryState.cleanupRequired;
      _errorMessage = 'Chưa thể hoàn tất dọn dẹp phiên khôi phục.';
    }
    notifyListeners();
    if (!clearSuccess) {
      throw StateError('Recovery marker cleanup failed');
    }
  }

  RecoveryState get state => _state;
  // Cleanup may still need its owner after mutation authority was revoked.
  PendingRecovery? get currentIntent => _currentIntent ?? _cleanupIntent;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get isReady => _state == RecoveryState.ready;
  bool get isProcessing =>
      _submitOwner != null ||
      _state == RecoveryState.verifying ||
      _state == RecoveryState.sending ||
      _state == RecoveryState.exchanging ||
      _state == RecoveryState.updating;
  bool get isCleanupRequired => _state == RecoveryState.cleanupRequired;

  Future<T> _markerMutation<T>(Future<T> Function() action) {
    final operation = _markerTail.then((_) => action());
    // Recover the tail for later operations; callers still receive this error.
    _markerTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  bool _ownsInput(String intentId, int generation) =>
      generation == _generation && _currentIntent?.intentId == intentId;

  Future<bool> _writeMarker(PendingRecovery intent, int generation) =>
      _markerMutation(() async {
        if (!_ownsInput(intent.intentId, generation)) return false;
        await store.write(intent);
        return _ownsInput(intent.intentId, generation);
      });

  Future<void> _clearMarker(String? intentId, {int? generation}) =>
      _markerMutation(() async {
        if (intentId == null &&
            generation != null &&
            generation != _generation) {
          return;
        }
        await store.clear(intentId);
      });

  SupabaseClient? get _client =>
      clientProvider?.call() ??
      (() {
        try {
          return Supabase.instance.client;
        } catch (_) {
          return null;
        }
      })();

  static String _generateIntentId() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> initializeFromStore() {
    return _initFuture ??= _performInitializeFromStore();
  }

  Future<void> retryVerification() async {
    if (_state != RecoveryState.verificationFailed) return;
    _state = RecoveryState.verifying;
    notifyListeners();
    _initFuture = null;
    await initializeFromStore();
  }

  void _checkPreflight(
    PendingRecovery intent,
    int generation,
    SupabaseClient client,
  ) {
    if (!_ownsInput(intent.intentId, generation) ||
        !auth.isCurrentRecoveryIntent(intent.intentId)) {
      throw RecoveryIntentCancelledException();
    }
    if (intent.isExpired(_clock())) {
      throw const _RecoveryPreflightFailure(
        'Yêu cầu khôi phục đã hết hạn. Vui lòng gửi yêu cầu mới.',
      );
    }
    final session = client.auth.currentSession;
    if (session == null ||
        session.isExpired ||
        intent.verifiedUserId == null ||
        session.user.id != intent.verifiedUserId) {
      throw const _RecoveryPreflightFailure(
        'Phiên khôi phục không hợp lệ hoặc đã hết hạn. Vui lòng gửi yêu cầu mới.',
      );
    }
  }

  Future<void> _verifyPreflight(
    PendingRecovery intent,
    int generation,
    SupabaseClient client,
  ) async {
    _checkPreflight(intent, generation, client);
    String? userId;
    try {
      userId = await service.verifyUser(client);
    } on AuthException catch (error) {
      final status = int.tryParse(error.statusCode ?? '');
      throw _RecoveryPreflightFailure(
        status == 401 || status == 403
            ? 'Phiên khôi phục đã bị từ chối. Vui lòng gửi yêu cầu mới.'
            : 'Chưa thể xác minh phiên với máy chủ. Mật khẩu chưa được gửi; vui lòng thử lại.',
        retryable: status == null || status >= 500 || status == 429,
      );
    } on FormatException {
      throw const _RecoveryPreflightFailure(
        'Phản hồi xác minh không hợp lệ. Vui lòng gửi yêu cầu mới.',
      );
    } catch (_) {
      throw const _RecoveryPreflightFailure(
        'Chưa thể xác minh phiên với máy chủ. Mật khẩu chưa được gửi; vui lòng thử lại.',
        retryable: true,
      );
    }
    _checkPreflight(intent, generation, client);
    if (userId == null || userId != intent.verifiedUserId) {
      throw const _RecoveryPreflightFailure(
        'Tài khoản xác minh không khớp. Vui lòng gửi yêu cầu mới.',
      );
    }
  }

  Future<void> _rejectPreflight(
    PendingRecovery intent,
    int generation,
    _RecoveryPreflightFailure failure, {
    required bool cold,
  }) async {
    if (!_ownsInput(intent.intentId, generation) ||
        !auth.isCurrentRecoveryIntent(intent.intentId)) {
      return;
    }
    if (failure.retryable) {
      if (!cold) {
        final ready = intent.copyWith(phase: RecoveryPhase.ready);
        try {
          if (!await _writeMarker(ready, generation)) return;
        } catch (_) {
          // No PUT was dispatched; retry must persist updating before sending.
        }
        if (!_ownsInput(intent.intentId, generation) ||
            !auth.isCurrentRecoveryIntent(intent.intentId)) {
          return;
        }
        // RAM can retry a known-undispatched operation even if restoring the
        // durable marker failed. A later submit still requires write-ahead.
        _currentIntent = ready;
      }
      if (!_ownsInput(intent.intentId, generation)) return;
      _state = cold ? RecoveryState.verificationFailed : RecoveryState.ready;
      _errorMessage = failure.message;
      notifyListeners();
      return;
    }
    await cancel();
    if (_generation == generation + 1 &&
        _currentIntent == null &&
        _state == RecoveryState.idle) {
      _state = RecoveryState.error;
      _errorMessage = failure.message;
      notifyListeners();
    }
  }

  Future<void> _performInitializeFromStore() async {
    final capturedGen = _generation;
    final previousIntent = _currentIntent;
    final intent = await store.read();
    if (_generation != capturedGen || auth.isGuest) {
      return;
    }
    if (intent == null) {
      if (previousIntent != null && previousIntent.isExpired(_clock())) {
        await _rejectPreflight(
          previousIntent,
          capturedGen,
          const _RecoveryPreflightFailure(
            'Yêu cầu khôi phục đã hết hạn. Vui lòng gửi yêu cầu mới.',
          ),
          cold: true,
        );
        return;
      }
      _state = RecoveryState.idle;
      _currentIntent = null;
      notifyListeners();
      return;
    }

    if (_state == RecoveryState.ready &&
        _currentIntent?.phase == RecoveryPhase.ready) {
      return;
    }

    _currentIntent = intent;
    await auth.beginRecovery(
      intent.intentId,
      verifiedUserId: intent.verifiedUserId,
    );
    if (_generation != capturedGen ||
        auth.isGuest ||
        !auth.isCurrentRecoveryIntent(intent.intentId)) {
      return;
    }

    if (intent.phase == RecoveryPhase.cleanup) {
      _state = RecoveryState.cleanupRequired;
      notifyListeners();
      return;
    }

    if (intent.phase == RecoveryPhase.updating) {
      _state = RecoveryState.uncertain;
      _errorMessage =
          'Yêu cầu cập nhật mật khẩu trước đó chưa xác định được kết quả.';
      notifyListeners();
      return;
    }

    if (intent.phase == RecoveryPhase.ready) {
      _state = RecoveryState.verifying;
      _errorMessage = null;
      notifyListeners();
      try {
        await auth.runRecoveryMutation(
          intent.intentId,
          (client) => _verifyPreflight(intent, capturedGen, client),
        );
        if (!_ownsInput(intent.intentId, capturedGen) ||
            !auth.isCurrentRecoveryIntent(intent.intentId)) {
          return;
        }
        _state = RecoveryState.ready;
        notifyListeners();
      } on RecoveryIntentCancelledException {
        return;
      } on _RecoveryPreflightFailure catch (failure) {
        await _rejectPreflight(intent, capturedGen, failure, cold: true);
      } catch (_) {
        await _rejectPreflight(
          intent,
          capturedGen,
          const _RecoveryPreflightFailure(
            'Chưa thể xác minh phiên với máy chủ. Vui lòng thử lại.',
            retryable: true,
          ),
          cold: true,
        );
      }
      return;
    }

    // Still awaiting callback link
    _state = RecoveryState.emailRequested;
    notifyListeners();
  }

  Future<void> requestEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      _errorMessage = 'Vui lòng nhập địa chỉ email hợp lệ.';
      notifyListeners();
      return;
    }

    if (_state == RecoveryState.sending) return;
    if (_authCleanupPending || (_cleanupIntent != null && isCleanupRequired)) {
      _errorMessage =
          'Vui lòng hoàn tất dọn dẹp phiên trước khi gửi yêu cầu mới.';
      notifyListeners();
      return;
    }

    final capturedGen = ++_generation;
    final intent = PendingRecovery(
      intentId: _generateIntentId(),
      requestedAt: _clock(),
      phase: RecoveryPhase.requesting,
    );

    _errorMessage = null;
    _successMessage = null;
    _state = RecoveryState.sending;
    _currentIntent = intent;
    notifyListeners();

    try {
      // 1. Write marker before dispatching network
      if (!await _writeMarker(intent, capturedGen)) return;
      if (_generation != capturedGen || auth.isGuest || auth.isAuthenticated) {
        try {
          await _clearMarker(intent.intentId);
        } catch (_) {}
        return;
      }

      await auth.beginRecovery(intent.intentId);
      if (_generation != capturedGen ||
          auth.isGuest ||
          !auth.isCurrentRecoveryIntent(intent.intentId)) {
        return;
      }

      // 2. Dispatch request
      await auth.runRecoveryMutation(
        intent.intentId,
        (client) => service.requestEmail(client, trimmed),
      );

      if (_generation != capturedGen ||
          !auth.isCurrentRecoveryIntent(intent.intentId)) {
        return;
      }

      final sentIntent = intent.copyWith(phase: RecoveryPhase.sent);
      if (!await _writeMarker(sentIntent, capturedGen)) return;
      if (_generation != capturedGen ||
          !auth.isCurrentRecoveryIntent(intent.intentId)) {
        return;
      }

      _currentIntent = sentIntent;
      _state = RecoveryState.emailRequested;
      _successMessage = 'Nếu email phù hợp trong hệ thống, bạn sẽ nhận được đường dẫn đặt lại mật khẩu.';
      notifyListeners();
    } on RecoveryIntentCancelledException {
      return;
    } on AuthException catch (e) {
      if (_generation != capturedGen || auth.isGuest) return;
      _errorMessage = e.message;
      _state = RecoveryState.error;
      notifyListeners();
    } catch (_) {
      if (_generation != capturedGen || auth.isGuest) return;
      _errorMessage =
          'Không thể gửi yêu cầu đặt lại mật khẩu; vui lòng thử lại.';
      _state = RecoveryState.error;
      notifyListeners();
    }
  }

  static bool _isValidRecoveryUri(Uri uri) {
    if (uri.scheme != 'io.supabase.travelgo' ||
        uri.host != 'login-callback' ||
        uri.path.isNotEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasFragment) {
      return false;
    }
    final paramsAll = uri.queryParametersAll;
    if (paramsAll['flow']?.length != 1 ||
        paramsAll['flow']!.first != 'recovery') {
      return false;
    }
    if (paramsAll['code']?.length != 1 ||
        paramsAll['code']!.first.trim().isEmpty) {
      return false;
    }
    if (paramsAll.keys.any((key) => key.contains('token'))) {
      return false;
    }
    return true;
  }

  Future<bool> handleCallback(Uri uri) async {
    if (_authCleanupPending ||
        (_cleanupIntent != null && _currentIntent == null)) {
      return false;
    }
    if (_state == RecoveryState.sending &&
        !auth.isCurrentRecoveryIntent(_currentIntent?.intentId ?? '')) {
      return false;
    }
    if (!_isValidRecoveryUri(uri)) {
      return false;
    }

    final code = uri.queryParameters['code']!.trim();

    // Idempotent duplicate check when already ready
    if (_state == RecoveryState.ready) {
      if (_activeExchangeCode == null || _activeExchangeCode == code) {
        _activeExchangeCode = code;
        return true;
      }
      return false;
    }

    // Join in-flight exchange if one is already running for the same code
    if (_inFlightExchange != null) {
      if (_activeExchangeCode == code) {
        return await _inFlightExchange!;
      }
      return false;
    }

    // Synchronously claim the in-flight slot for this code
    _activeExchangeCode = code;
    final capturedGen = _generation;
    final exchangeCompleter = Completer<bool>();
    _inFlightExchange = exchangeCompleter.future;

    try {
      // Await bootstrap if running, or bootstrap from store
      await (_initFuture ?? initializeFromStore());

      if (_generation != capturedGen || !auth.isRecovering) {
        if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(false);
        return false;
      }

      if (_state == RecoveryState.ready) {
        if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(true);
        return true;
      }

      final intent = _currentIntent ?? await store.read();
      if (intent == null || intent.isExpired(_clock())) {
        _errorMessage =
            'Yêu cầu khôi phục đã hết hạn. Vui lòng gửi lại email mới.';
        _state = RecoveryState.error;
        await _clearMarker(intent?.intentId, generation: capturedGen);
        notifyListeners();
        if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(false);
        return false;
      }

      if (intent.phase != RecoveryPhase.sent &&
          intent.phase != RecoveryPhase.requesting) {
        if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(false);
        return false;
      }

      final result = await _performExchange(intent, code, capturedGen);
      if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(result);
      return result;
    } catch (_) {
      if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(false);
      return false;
    } finally {
      if (identical(_inFlightExchange, exchangeCompleter.future)) {
        _inFlightExchange = null;
      }
      if (_generation == capturedGen && _state != RecoveryState.ready) {
        _activeExchangeCode = null;
      }
    }
  }

  Future<bool> _performExchange(
    PendingRecovery intent,
    String code,
    int capturedGen,
  ) async {
    _state = RecoveryState.exchanging;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await auth.runRecoveryMutation(
        intent.intentId,
        (client) => service.exchange(client, code),
      );

      if (_generation != capturedGen ||
          !auth.isCurrentRecoveryIntent(intent.intentId)) {
        await auth.performRecoverySignOut(
          intentId: intent.intentId,
          verifiedUserId: res.session.user.id,
        );
        return false;
      }

      final sessionUser = res.session.user;
      final readyIntent = intent.copyWith(
        phase: RecoveryPhase.ready,
        verifiedUserId: sessionUser.id,
      );
      if (!await _writeMarker(readyIntent, capturedGen)) return false;
      if (!auth.isCurrentRecoveryIntent(intent.intentId)) return false;

      _currentIntent = readyIntent;
      _state = RecoveryState.ready;
      _activeExchangeCode = code;
      notifyListeners();
      return true;
    } on RecoveryIntentCancelledException {
      return false;
    } on AuthException catch (e) {
      if (_generation != capturedGen ||
          !auth.isCurrentRecoveryIntent(intent.intentId)) {
        return false;
      }
      _errorMessage = 'Liên kết không hợp lệ hoặc đã qua sử dụng: ${e.message}';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    } catch (_) {
      if (_generation != capturedGen ||
          !auth.isCurrentRecoveryIntent(intent.intentId)) {
        return false;
      }
      _errorMessage = 'Không thể hoàn tất trao đổi mã khôi phục.';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitNewPassword(String password, String confirmation) async {
    if (_submitOwner != null ||
        _state == RecoveryState.updating ||
        _state == RecoveryState.cleanupRequired ||
        _state == RecoveryState.uncertain ||
        _state == RecoveryState.completed ||
        _state == RecoveryState.verifying ||
        _state == RecoveryState.verificationFailed) {
      return false;
    }
    final owner = Object();
    _submitOwner = owner;
    notifyListeners();
    try {
      return await _submitNewPassword(password, confirmation);
    } finally {
      if (identical(_submitOwner, owner)) {
        _submitOwner = null;
        notifyListeners();
      }
    }
  }

  Future<bool> _submitNewPassword(String password, String confirmation) async {
    final capturedGen = _generation;
    final trimmed = password.trim();
    if (trimmed.length < 8) {
      _errorMessage = 'Mật khẩu mới phải có tối thiểu 8 ký tự.';
      notifyListeners();
      return false;
    }

    if (trimmed != confirmation.trim()) {
      _errorMessage = 'Mật khẩu xác nhận không khớp.';
      notifyListeners();
      return false;
    }

    final intent = _currentIntent ?? await store.read();
    if (_generation != capturedGen) return false;
    if (intent == null || intent.phase != RecoveryPhase.ready) {
      _errorMessage = 'Phiên khôi phục không hợp lệ. Vui lòng gửi lại yêu cầu.';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    }
    if (!auth.isCurrentRecoveryIntent(intent.intentId)) return false;
    _currentIntent ??= intent;

    final client = _client;
    if (client == null) {
      _errorMessage = 'Phiên người dùng không khớp hoặc đã hết hạn.';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    }
    try {
      _checkPreflight(intent, capturedGen, client);
    } on RecoveryIntentCancelledException {
      return false;
    } on _RecoveryPreflightFailure catch (failure) {
      await _rejectPreflight(intent, capturedGen, failure, cold: false);
      return false;
    }

    if (_state == RecoveryState.updating ||
        _state == RecoveryState.cleanupRequired) {
      return false;
    }

    final updatingIntent = intent.copyWith(phase: RecoveryPhase.updating);
    try {
      if (!await _writeMarker(updatingIntent, capturedGen)) return false;
      _currentIntent = updatingIntent;
    } catch (_) {
      if (!_ownsInput(intent.intentId, capturedGen)) return false;
      _errorMessage =
          'Không thể ghi nhận trạng thái khôi phục trước khi đổi mật khẩu.';
      _state = RecoveryState.ready;
      notifyListeners();
      return false;
    }

    _state = RecoveryState.updating;
    _errorMessage = null;
    notifyListeners();

    try {
      await auth.runRecoveryMutation(intent.intentId, (client) async {
        await _verifyPreflight(intent, capturedGen, client);
        return service.updatePassword(client, trimmed);
      });

      if (!auth.isCurrentRecoveryIntent(intent.intentId)) {
        return false;
      }

      // Password updated successfully (ACK received).
      // Synchronously transition in RAM to cleanupRequired before any further awaits.
      _state = RecoveryState.cleanupRequired;
      final cleanupIntent = intent.copyWith(phase: RecoveryPhase.cleanup);
      _currentIntent = cleanupIntent;
      _cleanupIntent = cleanupIntent;

      try {
        if (!await _writeMarker(cleanupIntent, capturedGen)) return false;
        final signOutSuccess = await auth.performRecoverySignOut(
          intentId: intent.intentId,
          verifiedUserId: intent.verifiedUserId,
        );
        if (!signOutSuccess) {
          throw StateError('Failed to sign out recovery session.');
        }
        await _clearMarker(intent.intentId);
        await auth.finishRecovery(intent.intentId);
        if (!_ownsInput(intent.intentId, capturedGen)) return false;
        _cleanupIntent = null;
        _state = RecoveryState.completed;
        _successMessage = 'Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới.';
        notifyListeners();
        return true;
      } catch (_) {
        if (!_ownsInput(intent.intentId, capturedGen)) return false;
        _state = RecoveryState.cleanupRequired;
        _errorMessage = 'Đã đổi mật khẩu thành công, cần hoàn tất đăng xuất trước khi tiếp tục.';
        notifyListeners();
        return false;
      }
    } on RecoveryIntentCancelledException {
      return false;
    } on _RecoveryPreflightFailure catch (failure) {
      await _rejectPreflight(intent, capturedGen, failure, cold: false);
      return false;
    } on AuthException catch (e) {
      if (!auth.isCurrentRecoveryIntent(intent.intentId)) return false;
      final msg = e.message.toLowerCase();
      final isNetworkOrUncertain =
          e.statusCode == null ||
          msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('network') ||
          msg.contains('timeout') ||
          msg.contains('clientexception');

      if (isNetworkOrUncertain) {
        _state = RecoveryState.uncertain;
        _errorMessage = 'Kết nối mạng bị gián đoạn khi cập nhật mật khẩu. Vui lòng kiểm tra lại trạng thái tài khoản.';
      } else {
        try {
          final readyIntent = intent.copyWith(phase: RecoveryPhase.ready);
          if (!await _writeMarker(readyIntent, capturedGen)) return false;
          _currentIntent = readyIntent;
          _state = RecoveryState.ready;
        } catch (_) {
          _state = RecoveryState.uncertain;
        }
        _errorMessage = e.message;
      }
      notifyListeners();
      return false;
    } catch (_) {
      if (!_ownsInput(intent.intentId, capturedGen) ||
          !auth.isCurrentRecoveryIntent(intent.intentId)) {
        return false;
      }
      _state = RecoveryState.uncertain;
      _errorMessage = 'Kết nối mạng bị gián đoạn khi cập nhật mật khẩu. Vui lòng kiểm tra lại trạng thái tài khoản.';
      notifyListeners();
      return false;
    }
  }

  Future<void> retryCleanup() async {
    final intent = _cleanupIntent ?? _currentIntent ?? await store.read();
    if (intent == null) return;
    final intentId = intent.intentId;

    // If an authenticated account is already established in AuthProvider,
    // recovery cleanup is superseded and must not log out the active user.
    if (auth.currentUser != null) {
      if (_currentIntent == null || _currentIntent!.intentId == intentId) {
        _currentIntent = null;
        if (_cleanupIntent?.intentId == intentId) _cleanupIntent = null;
        _state = RecoveryState.idle;
        _errorMessage = null;
        notifyListeners();
      }
      return;
    }

    if (!auth.isCurrentRecoveryIntent(intentId)) {
      if (auth.isRecovering && _cleanupIntent?.intentId != intentId) {
        return;
      }
      final current = await store.read();
      if (current != null && current.intentId != intentId) {
        return;
      }
    }

    final signOutSuccess = await auth.performRecoverySignOut(
      intentId: intentId,
      verifiedUserId: intent.verifiedUserId,
    );

    // Recheck after await signOut
    if (auth.currentUser != null) {
      if (_currentIntent == null || _currentIntent!.intentId == intentId) {
        _currentIntent = null;
        if (_cleanupIntent?.intentId == intentId) _cleanupIntent = null;
        _state = RecoveryState.idle;
        _errorMessage = null;
        notifyListeners();
      }
      return;
    }

    bool clearSuccess = true;
    try {
      await _clearMarker(intentId);
    } catch (_) {
      clearSuccess = false;
    }

    // Recheck after await clear
    if (auth.currentUser != null) {
      if (_currentIntent == null || _currentIntent!.intentId == intentId) {
        _currentIntent = null;
        if (_cleanupIntent?.intentId == intentId) _cleanupIntent = null;
        _state = RecoveryState.idle;
        _errorMessage = null;
        notifyListeners();
      }
      return;
    }

    if (clearSuccess && signOutSuccess) {
      await auth.finishRecovery(intentId);
      if (_currentIntent == null || _currentIntent!.intentId == intentId) {
        _currentIntent = null;
        if (_cleanupIntent?.intentId == intentId) _cleanupIntent = null;
        _state = RecoveryState.completed;
        _errorMessage = null;
        _successMessage = 'Đã hoàn tất dọn dẹp phiên. Vui lòng đăng nhập lại.';
      }
    } else {
      if (_currentIntent == null || _currentIntent!.intentId == intentId) {
        _state = RecoveryState.cleanupRequired;
        _errorMessage = 'Vẫn chưa thể hoàn tất đăng xuất. Vui lòng thử lại.';
      }
    }
    if (_currentIntent == null || _currentIntent!.intentId == intentId) {
      notifyListeners();
    }
  }

  Future<void> cancel() async {
    final intent = _currentIntent ?? _cleanupIntent;
    final intentId = intent?.intentId;
    _generation++;
    _submitOwner = null;
    _initFuture = null;
    _inFlightExchange = null;
    _activeExchangeCode = null;

    // Synchronously revoke recovery authority before awaiting any async operation
    auth.revokeRecoveryAuthority(intentId);
    _cleanupIntent = intent;
    _currentIntent = null;
    _state = RecoveryState.idle;
    notifyListeners();

    PendingRecovery? actualIntent = intent;
    bool clearSuccess = true;
    try {
      await _markerMutation(() async {
        actualIntent ??= await store.read();
        _cleanupIntent ??= actualIntent;
        await store.clear(actualIntent?.intentId);
      });
    } catch (_) {
      clearSuccess = false;
    }

    final actualIntentId = actualIntent?.intentId;

    final signOutSuccess = await auth.performRecoverySignOut(
      intentId: actualIntentId ?? '',
      verifiedUserId: actualIntent?.verifiedUserId,
    );

    if (actualIntentId != null && clearSuccess && signOutSuccess) {
      await auth.finishRecovery(actualIntentId);
    }

    if (clearSuccess && signOutSuccess) {
      if (_cleanupIntent?.intentId == actualIntentId) _cleanupIntent = null;
      if (_currentIntent == null ||
          _currentIntent!.intentId == actualIntentId) {
        _currentIntent = null;
        _state = RecoveryState.idle;
        _errorMessage = null;
        _successMessage = null;
      }
    } else {
      if (_currentIntent == null ||
          _currentIntent!.intentId == actualIntentId) {
        _state = RecoveryState.cleanupRequired;
        _errorMessage =
            'Chưa thể hoàn tất dọn dẹp phiên khôi phục. Vui lòng thử lại.';
      }
    }

    if (_currentIntent == null || _currentIntent!.intentId == actualIntentId) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _removeRecoveryInvalidator?.call();
    _removeRecoveryCleanupResultListener?.call();
    super.dispose();
  }
}
