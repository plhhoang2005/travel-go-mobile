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

  PasswordRecoveryProvider({
    required this.service,
    required this.store,
    required this.auth,
    this.clientProvider,
    DateTime Function()? clock,
  })  : _clock = clock ?? (() => DateTime.now().toUtc());

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

  Future<void> initializeFromStore() async {
    final intent = await store.read();
    if (intent == null) {
      _state = RecoveryState.idle;
      _currentIntent = null;
      notifyListeners();
      return;
    }

    _currentIntent = intent;
    await auth.beginRecovery(intent.intentId);

    if (intent.phase == RecoveryPhase.cleanup) {
      _state = RecoveryState.cleanupRequired;
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

  Future<bool> handleCallback(Uri uri) async {
    if (uri.scheme != 'io.supabase.travelgo' ||
        uri.host != 'login-callback' ||
        uri.queryParameters['flow'] != 'recovery') {
      return false;
    }

    final code = uri.queryParameters['code'];
    if (code == null || code.trim().isEmpty) {
      _errorMessage = 'Liên kết xác thực thiếu mã ủy quyền.';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    }

    final intent = _currentIntent ?? await store.read();
    if (intent == null || intent.isExpired(_clock())) {
      _errorMessage = 'Yêu cầu khôi phục đã hết hạn. Vui lòng gửi lại email mới.';
      _state = RecoveryState.error;
      await store.clear();
      notifyListeners();
      return false;
    }

    _state = RecoveryState.exchanging;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await auth.runRecoveryMutation(
        intent.intentId,
        (client) => service.exchange(client, code),
      );

      final sessionUser = res.session.user;
      final readyIntent = intent.copyWith(
        phase: RecoveryPhase.ready,
        verifiedUserId: sessionUser.id,
      );
      await store.write(readyIntent);
      _currentIntent = readyIntent;
      _state = RecoveryState.ready;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = 'Liên kết không hợp lệ hoặc đã qua sử dụng: ${e.message}';
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    } catch (_) {
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

    if (_state == RecoveryState.updating) return false;

    _state = RecoveryState.updating;
    _errorMessage = null;
    notifyListeners();

    try {
      await auth.runRecoveryMutation(
        intent.intentId,
        (client) => service.updatePassword(client, trimmed),
      );

      // Password updated successfully. Transition to cleanup.
      final cleanupIntent = intent.copyWith(phase: RecoveryPhase.cleanup);
      await store.write(cleanupIntent);
      _currentIntent = cleanupIntent;

      try {
        final client = _client;
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
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _state = RecoveryState.error;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Không thể hoàn tất cập nhật mật khẩu; vui lòng thử lại.';
      _state = RecoveryState.error;
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
}
