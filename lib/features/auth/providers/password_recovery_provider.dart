import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/password_recovery_state.dart';
import '../services/password_recovery_service.dart';
import '../services/recovery_intent_store.dart';
import 'auth_provider.dart';

class PasswordRecoveryProvider extends ChangeNotifier {
  final PasswordRecoveryService service;
  final RecoveryIntentStore store;
  final AuthProvider auth;
  final SupabaseClient? Function()? clientProvider;
  final DateTime Function() _clock;

  RecoveryState _state = RecoveryState.idle;
  PendingRecovery? _currentIntent;
  String? _errorMessage;
  String? _successMessage;
  Future<void>? _initFuture;
  Future<bool>? _inFlightExchange;
  String? _activeExchangeCode;

  VoidCallback? _removeRecoveryInvalidator;

  PasswordRecoveryProvider({
    required this.service,
    required this.store,
    required this.auth,
    this.clientProvider,
    DateTime Function()? clock,
  })  : _clock = clock ?? (() => DateTime.now().toUtc()) {
    _removeRecoveryInvalidator = auth.registerRecoveryInvalidator(_handleRecoveryInvalidated);
  }

  Future<void> _handleRecoveryInvalidated() async {
    _state = RecoveryState.idle;
    _currentIntent = null;
    _errorMessage = null;
    _initFuture = null;
    _inFlightExchange = null;
    _activeExchangeCode = null;
    notifyListeners();
    try {
      await store.clear();
    } catch (_) {}
  }

  RecoveryState get state => _state;
  PendingRecovery? get currentIntent => _currentIntent;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool get isReady => _state == RecoveryState.ready;
  bool get isProcessing =>
      _state == RecoveryState.sending ||
      _state == RecoveryState.exchanging ||
      _state == RecoveryState.updating;
  bool get isCleanupRequired => _state == RecoveryState.cleanupRequired;

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

  Future<void> _performInitializeFromStore() async {
    final intent = await store.read();
    if (intent == null) {
      _state = RecoveryState.idle;
      _currentIntent = null;
      notifyListeners();
      return;
    }

    if (_state == RecoveryState.ready && _currentIntent?.phase == RecoveryPhase.ready) {
      return;
    }

    _currentIntent = intent;
    await auth.beginRecovery(intent.intentId);

    if (intent.phase == RecoveryPhase.cleanup) {
      _state = RecoveryState.cleanupRequired;
      notifyListeners();
      return;
    }

    if (intent.phase == RecoveryPhase.updating) {
      _state = RecoveryState.uncertain;
      _errorMessage = 'Yêu cầu cập nhật mật khẩu trước đó chưa xác định được kết quả.';
      notifyListeners();
      return;
    }

    if (intent.phase == RecoveryPhase.ready) {
      // Re-validate that client still holds an active session matching the intent
      final client = _client;
      final session = client?.auth.currentSession;
      if (session != null &&
          !session.isExpired &&
          intent.verifiedUserId != null &&
          session.user.id == intent.verifiedUserId) {
        _state = RecoveryState.ready;
      } else {
        await cancel();
      }
      notifyListeners();
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
      await store.write(intent);
      await auth.beginRecovery(intent.intentId);

      // 2. Dispatch request
      await auth.runRecoveryMutation(
        intent.intentId,
        (client) => service.requestEmail(client, trimmed),
      );

      final sentIntent = intent.copyWith(phase: RecoveryPhase.sent);
      await store.write(sentIntent);
      _currentIntent = sentIntent;
      _state = RecoveryState.emailRequested;
      _successMessage =
          'Nếu email phù hợp trong hệ thống, bạn sẽ nhận được đường dẫn đặt lại mật khẩu.';
      notifyListeners();
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _state = RecoveryState.error;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Không thể gửi yêu cầu đặt lại mật khẩu; vui lòng thử lại.';
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
    if (paramsAll['flow']?.length != 1 || paramsAll['flow']!.first != 'recovery') {
      return false;
    }
    if (paramsAll['code']?.length != 1 || paramsAll['code']!.first.trim().isEmpty) {
      return false;
    }
    if (paramsAll.keys.any((key) => key.contains('token'))) {
      return false;
    }
    return true;
  }

  Future<bool> handleCallback(Uri uri) async {
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
    final exchangeCompleter = Completer<bool>();
    _inFlightExchange = exchangeCompleter.future;

    try {
      // Await bootstrap if running, or bootstrap from store
      await (_initFuture ?? initializeFromStore());

      if (_state == RecoveryState.ready) {
        if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(true);
        return true;
      }

      final intent = _currentIntent ?? await store.read();
      if (intent == null || intent.isExpired(_clock())) {
        _errorMessage = 'Yêu cầu khôi phục đã hết hạn. Vui lòng gửi lại email mới.';
        _state = RecoveryState.error;
        await store.clear();
        notifyListeners();
        if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(false);
        return false;
      }

      if (intent.phase != RecoveryPhase.sent && intent.phase != RecoveryPhase.requesting) {
        if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(false);
        return false;
      }

      final result = await _performExchange(intent, code);
      if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(result);
      return result;
    } catch (_) {
      if (!exchangeCompleter.isCompleted) exchangeCompleter.complete(false);
      return false;
    } finally {
      _inFlightExchange = null;
    }
  }

  Future<bool> _performExchange(PendingRecovery intent, String code) async {
    _state = RecoveryState.exchanging;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await auth.runRecoveryMutation(
        intent.intentId,
        (client) => service.exchange(client, code),
      );

      if (!auth.isCurrentRecoveryIntent(intent.intentId)) {
        return false;
      }

      final sessionUser = res.session.user;
      final readyIntent = intent.copyWith(
        phase: RecoveryPhase.ready,
        verifiedUserId: sessionUser.id,
      );
      await store.write(readyIntent);
      _currentIntent = readyIntent;
      _state = RecoveryState.ready;
      _activeExchangeCode = code;
      notifyListeners();
      return true;
    } on RecoveryIntentCancelledException {
      return false;
    } on AuthException catch (e) {
      if (!auth.isCurrentRecoveryIntent(intent.intentId)) return false;
      _errorMessage = 'Liên kết không hợp lệ hoặc đã qua sử dụng: ${e.message}';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    } catch (_) {
      if (!auth.isCurrentRecoveryIntent(intent.intentId)) return false;
      _errorMessage = 'Không thể hoàn tất trao đổi mã khôi phục.';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitNewPassword(String password, String confirmation) async {
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
    if (intent == null || intent.phase != RecoveryPhase.ready) {
      _errorMessage = 'Phiên khôi phục không hợp lệ. Vui lòng gửi lại yêu cầu.';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    }

    final client = _client;
    final currentSession = client?.auth.currentSession;
    if (currentSession == null ||
        currentSession.isExpired ||
        currentSession.user.id != intent.verifiedUserId) {
      _errorMessage = 'Phiên người dùng không khớp hoặc đã hết hạn.';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    }

    if (_state == RecoveryState.updating || _state == RecoveryState.cleanupRequired) {
      return false;
    }

    final updatingIntent = intent.copyWith(phase: RecoveryPhase.updating);
    try {
      await store.write(updatingIntent);
      _currentIntent = updatingIntent;
    } catch (_) {
      _errorMessage = 'Không thể ghi nhận trạng thái khôi phục trước khi đổi mật khẩu.';
      _state = RecoveryState.ready;
      notifyListeners();
      return false;
    }

    _state = RecoveryState.updating;
    _errorMessage = null;
    notifyListeners();

    try {
      await auth.runRecoveryMutation(
        intent.intentId,
        (client) => service.updatePassword(client, trimmed),
      );

      if (!auth.isCurrentRecoveryIntent(intent.intentId)) {
        return false;
      }

      // Password updated successfully (ACK received).
      // Synchronously transition in RAM to cleanupRequired before any further awaits.
      _state = RecoveryState.cleanupRequired;
      final cleanupIntent = intent.copyWith(phase: RecoveryPhase.cleanup);
      _currentIntent = cleanupIntent;

      try {
        await store.write(cleanupIntent);
        if (client != null) {
          await client.auth.signOut(scope: SignOutScope.local);
        }
        await store.clear();
        await auth.finishRecovery(intent.intentId);
        _state = RecoveryState.completed;
        _successMessage =
            'Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới.';
        notifyListeners();
        return true;
      } catch (_) {
        _state = RecoveryState.cleanupRequired;
        _errorMessage =
            'Đã đổi mật khẩu thành công, cần hoàn tất đăng xuất trước khi tiếp tục.';
        notifyListeners();
        return false;
      }
    } on RecoveryIntentCancelledException {
      return false;
    } on AuthException catch (e) {
      if (!auth.isCurrentRecoveryIntent(intent.intentId)) return false;
      final msg = e.message.toLowerCase();
      final isNetworkOrUncertain = e.statusCode == null ||
          msg.contains('socket') ||
          msg.contains('connection') ||
          msg.contains('network') ||
          msg.contains('timeout') ||
          msg.contains('clientexception');

      if (isNetworkOrUncertain) {
        _state = RecoveryState.uncertain;
        _errorMessage =
            'Kết nối mạng bị gián đoạn khi cập nhật mật khẩu. Vui lòng kiểm tra lại trạng thái tài khoản.';
      } else {
        try {
          final readyIntent = intent.copyWith(phase: RecoveryPhase.ready);
          await store.write(readyIntent);
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
      _state = RecoveryState.uncertain;
      _errorMessage =
          'Kết nối mạng bị gián đoạn khi cập nhật mật khẩu. Vui lòng kiểm tra lại trạng thái tài khoản.';
      notifyListeners();
      return false;
    }
  }

  Future<void> retryCleanup() async {
    final intent = _currentIntent;
    if (intent == null) return;

    try {
      final client = _client;
      if (client != null) {
        await client.auth.signOut(scope: SignOutScope.local);
      }
      await store.clear();
      await auth.finishRecovery(intent.intentId);
      _state = RecoveryState.completed;
      _errorMessage = null;
      _successMessage = 'Đã hoàn tất dọn dẹp phiên. Vui lòng đăng nhập lại.';
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Vẫn chưa thể hoàn tất đăng xuất. Vui lòng thử lại.';
      notifyListeners();
    }
  }

  Future<void> cancel() async {
    final intent = _currentIntent;
    _currentIntent = null;
    _state = RecoveryState.idle;
    _errorMessage = null;
    _successMessage = null;
    _initFuture = null;
    _inFlightExchange = null;
    _activeExchangeCode = null;

    try {
      await store.clear();
      if (intent != null) {
        final client = _client;
        if (client != null) {
          await client.auth.signOut(scope: SignOutScope.local);
        }
        await auth.finishRecovery(intent.intentId);
      }
    } catch (_) {}

    notifyListeners();
  }

  @override
  void dispose() {
    _removeRecoveryInvalidator?.call();
    super.dispose();
  }
}
