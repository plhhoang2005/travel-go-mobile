import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../trip_planner/models/local_ai_models.dart';
import '../../trip_planner/models/local_ai_settings.dart';
import '../../trip_planner/services/local_ai_service.dart';
import '../models/ai_chat_session.dart';
import '../services/ai_chat_storage_service.dart';
import '../services/local_ai_quota_service.dart';
import '../services/local_ai_settings_store.dart';

class _ChatPersistenceState {
  LocalAiFailure? failure;
  String? failedMessageId;
  bool hasUnsavedReply = false;
  int requestGeneration = -1;
}

/// Owns local chat requests; cloud AI and automatic fallback are not used.
class AiChatProvider extends ChangeNotifier {
  final AiChatStorageService storageService;
  final LocalAiService aiService;
  final LocalAiSettingsStore settingsStore;
  final LocalAiQuotaService quotaService;
  LocalAiSettings _settings = LocalAiSettings();
  bool _isAdmin = false;
  int _remainingQuota = 10;
  List<AiChatSession> _sessions = [];
  AiChatSession? _currentSession;
  List<AiChatMessage> _messages = [];
  final Map<String, List<AiChatMessage>> _messageCache = {};
  Future<void>? _initialization;
  Future<void> _writeQueue = Future<void>.value();
  bool _initialized = false;
  bool _isLoading = false;
  bool _navigating = false;
  bool _disposed = false;
  final Map<String, _ChatPersistenceState> _persistenceStates = {};
  _ChatPersistenceState get _persistence => _persistenceStates.putIfAbsent(
    _currentSession?.id ?? '',
    _ChatPersistenceState.new,
  );
  bool get _hasUnsavedReply => _persistence.hasUnsavedReply;
  set _hasUnsavedReply(bool value) => _persistence.hasUnsavedReply = value;
  int _generation = 0;
  int _idSequence = 0;
  CancelToken? _cancelToken;
  LocalAiFailure? get _lastFailure => _persistence.failure;
  set _lastFailure(LocalAiFailure? value) => _persistence.failure = value;
  String? get _failedMessageId => _persistence.failedMessageId;
  set _failedMessageId(String? value) => _persistence.failedMessageId = value;

  AiChatProvider({
    AiChatStorageService? storageService,
    LocalAiService? aiService,
    LocalAiSettingsStore? settingsStore,
    LocalAiQuotaService? quotaService,
  }) : storageService = storageService ?? AiChatStorageService(),
       aiService = aiService ?? LocalAiService(dio: Dio()),
       settingsStore = settingsStore ?? LocalAiSettingsStore(),
       quotaService = quotaService ?? LocalAiQuotaService();

  List<AiChatSession> get sessions => List.unmodifiable(_sessions);
  AiChatSession? get currentSession => _currentSession;
  List<AiChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  bool get isReady => _initialized && !_navigating && !_disposed;
  bool get isQuotaExhausted => !_isAdmin && _remainingQuota <= 0;
  bool get canSend =>
      isReady &&
      !_isLoading &&
      !isQuotaExhausted &&
      _lastFailure?.code != LocalAiFailureCode.storage;
  bool get isAdmin => _isAdmin;
  int get remainingQuota => _remainingQuota;
  LocalAiSettings get settings => _settings;
  String get selectedModel => _settings.modelName;
  String? get settingsWarning => settingsStore.loadWarning;
  LocalAiFailure? get lastFailure => _lastFailure;
  String? get failedMessageId => _failedMessageId;

  void updateRole({required bool isAdmin}) {
    if (_isAdmin != isAdmin) {
      _isAdmin = isAdmin;
      unawaited(refreshQuota());
    }
  }

  Future<void> refreshQuota() async {
    final remaining = await quotaService.getRemainingQuota(
      dailyQuota: _settings.dailyQuota,
      isAdmin: _isAdmin,
    );
    if (!_disposed) {
      _remainingQuota = remaining;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_idSequence++}';
  bool _isCurrent(int generation, String sessionId) =>
      !_disposed &&
      generation == _generation &&
      _currentSession?.id == sessionId;

  Future<void> reloadAiSettings() async {
    final loaded = await settingsStore.load();
    if (_disposed) return;
    _settings = loaded;
    await refreshQuota();
    _notify();
  }

  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      await reloadAiSettings();
      final sessions = await storageService.loadSessions();
      if (_disposed) return;
      _sessions = sessions;
      if (_sessions.isEmpty) {
        _newSession('Cuộc trò chuyện mới');
        await _persistCurrent();
      } else {
        _currentSession = _sessions.first;
        final loaded = await storageService.loadMessages(_currentSession!.id);
        if (_disposed) return;
        _messages = loaded;
        _messageCache[_currentSession!.id] = _messages;
      }
      _initialized = true;
    } catch (_) {
      _lastFailure = _storageFailure;
    } finally {
      _notify();
    }
  }

  void _newSession(String title) {
    final now = DateTime.now();
    final session = AiChatSession(
      id: _id('session'),
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    _sessions.insert(0, session);
    _currentSession = session;
    _messages = [];
    _messageCache[session.id] = _messages;
  }

  Future<void> createNewSession({String? initialTitle}) async {
    if (_disposed || _navigating || !_initialized) return;
    cancelPendingReply();
    _newSession(initialTitle ?? 'Cuộc trò chuyện mới');
    _navigating = true;
    _notify();
    try {
      await _persistCurrent();
    } catch (_) {
      _lastFailure = _storageFailure;
    } finally {
      _navigating = false;
      _notify();
    }
  }

  Future<void> selectSession(String sessionId) async {
    if (_disposed || _navigating || !_sessions.any((s) => s.id == sessionId)) {
      return;
    }
    cancelPendingReply();
    final generation = _generation;
    _navigating = true;
    _notify();
    try {
      final loaded =
          _messageCache[sessionId] ??
          await storageService.loadMessages(sessionId);
      if (_disposed || generation != _generation) return;
      _currentSession = _sessions.firstWhere((s) => s.id == sessionId);
      _messages = loaded;
      _messageCache[sessionId] = loaded;
    } catch (_) {
      _lastFailure = _storageFailure;
    } finally {
      _navigating = false;
      _notify();
    }
  }

  Future<void> renameSession(String sessionId, String newTitle) async {
    final clean = newTitle.trim();
    if (clean.isEmpty || _disposed || _navigating) return;
    try {
      await _write(() => storageService.renameSession(sessionId, clean));
      if (_disposed) return;
      _sessions = _sessions
          .map((s) => s.id == sessionId ? s.copyWith(title: clean) : s)
          .toList();
      if (_currentSession?.id == sessionId) {
        _currentSession = _currentSession!.copyWith(title: clean);
      }
    } catch (_) {
      _lastFailure = _storageFailure;
    }
    _notify();
  }

  Future<void> deleteSession(String sessionId) async {
    if (_disposed || _navigating) return;
    cancelPendingReply();
    _navigating = true;
    _notify();
    try {
      await _write(() => storageService.deleteSession(sessionId));
      if (_disposed) return;
      _sessions.removeWhere((s) => s.id == sessionId);
      _messageCache.remove(sessionId);
      _persistenceStates.remove(sessionId);
      if (_currentSession?.id == sessionId) {
        if (_sessions.isEmpty) {
          _newSession('Cuộc trò chuyện mới');
          await _persistCurrent();
        } else {
          _currentSession = _sessions.first;
          _messages =
              _messageCache[_currentSession!.id] ??
              await storageService.loadMessages(_currentSession!.id);
          _messageCache[_currentSession!.id] = _messages;
        }
      }
    } catch (_) {
      _lastFailure = _storageFailure;
    } finally {
      _navigating = false;
      _notify();
    }
  }

  Future<void> sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty ||
        _isLoading ||
        !isReady ||
        _lastFailure?.code == LocalAiFailureCode.storage) {
      return;
    }
    final allowed = await quotaService.canSend(
      dailyQuota: _settings.dailyQuota,
      isAdmin: _isAdmin,
    );
    if (!allowed) {
      _lastFailure = LocalAiFailure(
        LocalAiFailureCode.quotaExceeded,
        'Bạn đã dùng hết ${_settings.dailyQuota} lượt hỏi AI hôm nay. Vui lòng quay lại vào ngày mai!',
      );
      _notify();
      return;
    }
    final message = AiChatMessage(
      id: _id('msg'),
      sessionId: _currentSession!.id,
      content: query,
      sender: ChatSender.user,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    if (_currentSession!.title == 'Cuộc trò chuyện mới' ||
        _currentSession!.title.isEmpty) {
      _updateSession(
        _currentSession!.copyWith(
          title: query.length > 28 ? '${query.substring(0, 28)}...' : query,
        ),
      );
    }
    await _sendExisting(message);
  }

  Future<void> regenerateAiReply(String messageId) async {
    if (_isLoading ||
        !isReady ||
        _currentSession == null ||
        _lastFailure?.code == LocalAiFailureCode.storage) {
      return;
    }
    final targetIndex =
        _messages.indexWhere((m) => m.id == messageId && !m.isUser);
    if (targetIndex == -1) return;

    final allowed = await quotaService.canSend(
      dailyQuota: _settings.dailyQuota,
      isAdmin: _isAdmin,
    );
    if (!allowed) {
      _lastFailure = LocalAiFailure(
        LocalAiFailureCode.quotaExceeded,
        'Bạn đã dùng hết  lượt hỏi AI hôm nay. Vui lòng quay lại vào ngày mai!',
      );
      _notify();
      return;
    }

    AiChatMessage? precedingUserMessage;
    for (int i = targetIndex - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        precedingUserMessage = _messages[i];
        break;
      }
    }
    if (precedingUserMessage == null) return;

    _messages.removeAt(targetIndex);
    _notify();
    await _sendExisting(precedingUserMessage);
  }

  void _updateSession(AiChatSession session) {
    _currentSession = session;
    final index = _sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) _sessions[index] = session;
  }

  Future<void> _write(Future<void> Function() operation) {
    final result = _writeQueue.then((_) => operation());
    _writeQueue = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _persistCurrent() {
    final id = _currentSession!.id;
    final messages = List<AiChatMessage>.of(_messages);
    final sessions = List<AiChatSession>.of(_sessions);
    return _write(() async {
      await storageService.saveMessages(id, messages);
      await storageService.saveSessions(sessions);
    });
  }

  static const _storageFailure = LocalAiFailure(
    LocalAiFailureCode.storage,
    'Chưa lưu được hội thoại trên thiết bị. Nội dung đang được giữ trong bộ nhớ; hãy thử lưu lại.',
  );

  Future<void> _sendExisting(AiChatMessage message) async {
    final generation = ++_generation;
    final persistence = _persistence;
    persistence.requestGeneration = generation;
    final sessionId = message.sessionId;
    final settings = _settings;
    final token = CancelToken();
    _cancelToken = token;
    _isLoading = true;
    _lastFailure = null;
    _failedMessageId = message.id;
    _hasUnsavedReply = false;
    _notify();
    try {
      try {
        await _persistCurrent();
      } catch (_) {
        throw _storageFailure;
      }
      if (!_isCurrent(generation, sessionId)) return;
      final reply = await aiService.requestReply(
        message.content,
        settings: settings,
        cancelToken: token,
      );
      if (!_isCurrent(generation, sessionId)) return;
      await quotaService.recordUsage(isAdmin: _isAdmin);
      await refreshQuota();
      _messages.add(
        AiChatMessage(
          id: _id('msg'),
          sessionId: sessionId,
          content: reply,
          sender: ChatSender.ai,
          timestamp: DateTime.now(),
        ),
      );
      _updateSession(
        _currentSession!.copyWith(
          updatedAt: DateTime.now(),
          previewSnippet: reply.length > 50
              ? '${reply.substring(0, 50)}...'
              : reply,
        ),
      );
      _hasUnsavedReply = true;
      try {
        await _persistCurrent();
      } catch (_) {
        throw _storageFailure;
      }
      if (persistence.requestGeneration == generation) {
        persistence.hasUnsavedReply = false;
        persistence.failedMessageId = null;
        persistence.failure = null;
      }
    } on LocalAiFailure catch (failure) {
      if (_isCurrent(generation, sessionId) ||
          (!_disposed &&
              failure.code == LocalAiFailureCode.storage &&
              persistence.requestGeneration == generation &&
              _sessions.any((s) => s.id == sessionId))) {
        persistence.failure = failure;
      }
    } catch (_) {
      if (_isCurrent(generation, sessionId)) {
        _lastFailure = const LocalAiFailure(
          LocalAiFailureCode.server,
          'Không nhận được câu trả lời từ Ollama. Vui lòng thử lại.',
        );
      }
    } finally {
      if (_isCurrent(generation, sessionId)) {
        _isLoading = false;
        _cancelToken = null;
        _notify();
      }
    }
  }

  Future<void> retryFailedMessage() async {
    if (_isLoading || _disposed || _navigating) return;
    if (!_initialized) {
      _isLoading = true;
      _notify();
      try {
        if (_currentSession != null) {
          await _persistCurrent();
          _initialized = true;
          _lastFailure = null;
        } else {
          _initialization = null;
          await init();
        }
      } catch (_) {
        _lastFailure = _storageFailure;
      } finally {
        _isLoading = false;
        _notify();
      }
      return;
    }
    if (_lastFailure?.code == LocalAiFailureCode.storage &&
        (_hasUnsavedReply || _failedMessageId == null)) {
      _isLoading = true;
      _notify();
      final generation = _generation;
      final sessionId = _currentSession!.id;
      final persistence = _persistence;
      try {
        await _persistCurrent();
        persistence.failure = null;
        persistence.hasUnsavedReply = false;
        persistence.failedMessageId = null;
      } catch (_) {
        persistence.failure = _storageFailure;
      } finally {
        if (_isCurrent(generation, sessionId)) {
          _isLoading = false;
          _notify();
        }
      }
      return;
    }
    final failed = _messages.where((m) => m.id == _failedMessageId && m.isUser);
    if (failed.isNotEmpty) await _sendExisting(failed.single);
  }

  void cancelPendingReply() {
    _generation++;
    _cancelToken?.cancel();
    _cancelToken = null;
    _isLoading = false;
    if (_lastFailure?.code != LocalAiFailureCode.storage && !_hasUnsavedReply) {
      _lastFailure = null;
      _failedMessageId = null;
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancelToken?.cancel();
    super.dispose();
  }
}
