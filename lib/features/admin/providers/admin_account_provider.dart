// State management for TravelGO administration.
// Stores all administrative PII strictly in RAM; invalidated on owner or role change.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/services/admin_account_service.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

class AdminAccountProvider extends ChangeNotifier {
  final AdminAccountService service;
  final AuthProvider authProvider;

  String? _currentOwnerId;
  String? _currentRole;
  int _authEpoch = 0;
  int _contextGeneration = 0;
  int _accessGeneration = 0;
  bool _disposed = false;

  // RAM-only administrative data
  bool _hasAdminAccess = false;
  List<UserSummary> _users = const [];
  UserCursor? _nextCursor;
  UserDetail? _selectedUser;
  DashboardSnapshot? _dashboardSnapshot;
  AccountOperation? _pendingOperation;
  AdminFailure? _error;

  // Loading states
  bool _isLoadingUsers = false;
  bool _isLoadingDetail = false;
  bool _isLoadingDashboard = false;
  bool _isMutating = false;

  // Filters & Query
  String _query = '';
  String? _roleFilter;
  String? _stateFilter;
  Timer? _debounceTimer;

  // Generation guards to avoid race conditions across async requests
  int _usersGeneration = 0;
  int _detailGeneration = 0;
  int _dashboardGeneration = 0;

  // Track pending mutation arguments for idempotent retries with same requestId
  Map<String, dynamic>? _pendingMutationArgs;
  Map<String, dynamic>? _reconcileArgs;
  bool _readbackNeeded = false;
  bool get hasRetryableOperation => _pendingMutationArgs != null;
  bool get needsReadback => _readbackNeeded;
  String? get pendingTargetId => _pendingMutationArgs?['targetId'] as String?;

  AdminAccountProvider({required this.service, required this.authProvider}) {
    _currentOwnerId = authProvider.currentUser?.id;
    _currentRole = authProvider.currentUser?.role.name;
    _authEpoch = authProvider.authEpoch;
    authProvider.addListener(_handleAuthChange);
  }

  // Getters
  bool get hasAdminAccess => _hasAdminAccess;
  List<UserSummary> get users => List.unmodifiable(_users);
  bool get hasMoreUsers => _nextCursor != null;
  UserDetail? get selectedUser => _selectedUser;
  DashboardSnapshot? get dashboardSnapshot => _dashboardSnapshot;
  AccountOperation? get pendingOperation => _pendingOperation;
  AdminFailure? get error => _error;

  bool get isLoadingUsers => _isLoadingUsers;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isLoadingDashboard => _isLoadingDashboard;
  bool get isMutating => _isMutating;

  String get query => _query;
  String? get roleFilter => _roleFilter;
  String? get stateFilter => _stateFilter;

  void _handleAuthChange() {
    final newOwnerId = authProvider.currentUser?.id;
    final newRole = authProvider.currentUser?.role.name;

    if (newOwnerId != _currentOwnerId ||
        newRole != _currentRole ||
        _authEpoch != authProvider.authEpoch ||
        authProvider.isLoggingOut ||
        authProvider.isDemoSession) {
      _currentOwnerId = newOwnerId;
      _currentRole = newRole;
      _authEpoch = authProvider.authEpoch;
      invalidate();
    }
  }

  void invalidate() {
    _contextGeneration++;
    _accessGeneration++;
    _debounceTimer?.cancel();
    _debounceTimer = null;

    // Bump generations to invalidate any in-flight requests
    _usersGeneration++;
    _detailGeneration++;
    _dashboardGeneration++;

    _hasAdminAccess = false;
    _users = const [];
    _nextCursor = null;
    _selectedUser = null;
    _dashboardSnapshot = null;
    _pendingOperation = null;
    _pendingMutationArgs = null;
    _reconcileArgs = null;
    _readbackNeeded = false;
    _error = null;

    _isLoadingUsers = false;
    _isLoadingDetail = false;
    _isLoadingDashboard = false;
    _isMutating = false;
    _query = '';
    _roleFilter = null;
    _stateFilter = null;

    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> enter() async {
    final gen = ++_accessGeneration;
    final context = _contextGeneration;
    _error = null;
    if (_currentOwnerId == null ||
        _currentRole != 'admin' ||
        authProvider.isDemoSession ||
        authProvider.isLoggingOut) {
      invalidate();
      return;
    }
    try {
      final access = await service.access();
      if (!_isCurrent(context) || gen != _accessGeneration) return;
      _hasAdminAccess =
          access.allowed &&
          access.role == 'admin' &&
          access.subjectId == _currentOwnerId;
    } on AdminFailure catch (f) {
      if (!_isCurrent(context) || gen != _accessGeneration) return;
      _hasAdminAccess = false;
      _error = f;
    } catch (e) {
      if (!_isCurrent(context) || gen != _accessGeneration) return;
      _hasAdminAccess = false;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (_isCurrent(context) && gen == _accessGeneration) notifyListeners();
    }
  }

  bool _isCurrent(int context) =>
      !_disposed &&
      context == _contextGeneration &&
      _authEpoch == authProvider.authEpoch &&
      _currentOwnerId == authProvider.currentUser?.id &&
      _currentRole == authProvider.currentUser?.role.name;

  void _fail(AdminFailure failure) {
    if (const {
      'unauthorized',
      'forbidden',
      'admin_required',
      'account_locked',
      'stale_session',
      'invalid_session',
    }.contains(failure.code)) {
      invalidate();
    }
    _error = failure;
  }

  static const _unchanged = Object();
  void setFilter({
    String? query,
    Object? role = _unchanged,
    Object? state = _unchanged,
  }) {
    var changed = false;
    if (query != null && query != _query) {
      _query = query;
      changed = true;
    }
    if (!identical(role, _unchanged) && role != _roleFilter) {
      _roleFilter = role as String?;
      changed = true;
    }
    if (!identical(state, _unchanged) && state != _stateFilter) {
      _stateFilter = state as String?;
      changed = true;
    }

    if (changed) {
      _usersGeneration++;
      _users = const [];
      _nextCursor = null;
      _isLoadingUsers = false;
      _error = null;
      _isLoadingUsers = true;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        loadUsers(nextPage: false);
      });
      notifyListeners();
    }
  }

  Future<void> loadUsers({bool nextPage = false}) async {
    if (_disposed) return;
    if (_isLoadingUsers && nextPage) return;
    if (nextPage && _nextCursor == null) return;
    _debounceTimer?.cancel();
    final context = _contextGeneration;

    final gen = ++_usersGeneration;
    _isLoadingUsers = true;
    _error = null;
    notifyListeners();

    try {
      final page = await service.listUsers(
        query: _query,
        role: _roleFilter,
        state: _stateFilter,
        cursor: nextPage ? _nextCursor : null,
      );

      // Verify generation matches current epoch
      if (gen != _usersGeneration || !_isCurrent(context)) return;

      if (nextPage) {
        final byId = {
          for (final user in _users) user.id: user,
          for (final user in page.items) user.id: user,
        };
        _users = byId.values.toList(growable: false);
      } else {
        _users = page.items;
      }
      _nextCursor = page.nextCursor;
    } on AdminFailure catch (f) {
      if (gen != _usersGeneration || !_isCurrent(context)) return;
      _fail(f);
    } catch (e) {
      if (gen != _usersGeneration || !_isCurrent(context)) return;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (gen == _usersGeneration && _isCurrent(context)) {
        _isLoadingUsers = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectUser(String id) async {
    final context = _contextGeneration;
    final gen = ++_detailGeneration;
    _selectedUser = null;
    _isLoadingDetail = true;
    _error = null;
    notifyListeners();

    try {
      final detail = await service.getUser(id);
      if (gen != _detailGeneration || !_isCurrent(context)) return;
      if (detail.id != id) {
        throw const AdminFailure(
          code: 'invalid_response',
          message: 'Wrong user',
        );
      }
      _selectedUser = detail;
      final pending = detail.pendingOperation;
      if (_pendingMutationArgs == null &&
          pending != null &&
          pending.targetId == detail.id &&
          pending.targetRevision == detail.revision &&
          !pending.isCompleted) {
        _pendingOperation = pending;
        final audit = detail.audit
            .where((event) => event.operationId == pending.id)
            .firstOrNull;
        _pendingMutationArgs = {
          'requestId': pending.id,
          'targetId': pending.targetId,
          'expectedRevision': pending.targetRevision - 1,
          'action': pending.action,
          'reason': audit?.reason ?? 'Đồng bộ lại xác thực',
        };
        _readbackNeeded = false;
      }
    } on AdminFailure catch (f) {
      if (gen != _detailGeneration || !_isCurrent(context)) return;
      _fail(f);
    } catch (e) {
      if (gen != _detailGeneration || !_isCurrent(context)) return;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (gen == _detailGeneration && _isCurrent(context)) {
        _isLoadingDetail = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadDashboard(int days) async {
    final context = _contextGeneration;
    final gen = ++_dashboardGeneration;
    _isLoadingDashboard = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await service.dashboard(days: days);
      if (gen != _dashboardGeneration || !_isCurrent(context)) return;
      _dashboardSnapshot = snapshot;
    } on AdminFailure catch (f) {
      if (gen != _dashboardGeneration || !_isCurrent(context)) return;
      _fail(f);
    } catch (e) {
      if (gen != _dashboardGeneration || !_isCurrent(context)) return;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (gen == _dashboardGeneration && _isCurrent(context)) {
        _isLoadingDashboard = false;
        notifyListeners();
      }
    }
  }

  static String _mintRequestId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // v4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // rfc4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<bool> confirmMutation({
    required String targetId,
    required int expectedRevision,
    required String action,
    required String reason,
  }) async {
    if (_isMutating || _disposed) return false;
    if (_pendingMutationArgs != null) return retryOperation();

    _pendingOperation = null;
    _reconcileArgs = null;
    _readbackNeeded = false;

    final requestId = _mintRequestId();
    _pendingMutationArgs = {
      'requestId': requestId,
      'targetId': targetId,
      'expectedRevision': expectedRevision,
      'action': action,
      'reason': reason,
    };

    return _dispatchMutation(_pendingMutationArgs!);
  }

  Future<bool> retryOperation() async {
    if (_isMutating) return false;
    if (_pendingMutationArgs == null) return false;

    // Retry sending exact same requestId and arguments
    return _dispatchMutation(_pendingMutationArgs!, retry: true);
  }

  Future<bool> _dispatchMutation(
    Map<String, dynamic> args, {
    bool retry = false,
  }) async {
    final context = _contextGeneration;
    final selectedId = _selectedUser?.id;
    final detailGen = _detailGeneration;
    _isMutating = true;
    _error = null;
    notifyListeners();

    try {
      AccountOperation op;
      if (_readbackNeeded && _pendingOperation?.isCompleted == true) {
        op = _pendingOperation!;
      } else if (retry && _pendingOperation != null) {
        op = await service.operation(_pendingOperation!.id);
        if (!_isCurrent(context)) return false;
        _checkOperation(op, args);
        if (!op.isCompleted) {
          _reconcileArgs ??= {
            'requestId': _mintRequestId(),
            'operationId': op.id,
            'expectedRevision': op.targetRevision,
            'reason': args['reason'],
          };
          op = await service.reconcile(
            requestId: _reconcileArgs!['requestId'] as String,
            operationId: _reconcileArgs!['operationId'] as String,
            expectedRevision: _reconcileArgs!['expectedRevision'] as int,
            reason: _reconcileArgs!['reason'] as String,
          );
        }
      } else {
        op = await service.mutate(
          requestId: args['requestId'] as String,
          targetId: args['targetId'] as String,
          expectedRevision: args['expectedRevision'] as int,
          action: args['action'] as String,
          reason: args['reason'] as String,
        );
      }
      if (!_isCurrent(context)) return false;
      _checkOperation(op, args);
      _pendingOperation = op;
      final targetId = args['targetId'] as String;
      _readbackNeeded = true;
      final detail = await service.getUser(targetId);
      if (!_isCurrent(context)) return false;
      if (detail.id != targetId || detail.revision < op.targetRevision) {
        throw const AdminFailure(
          code: 'invalid_response',
          message: 'Wrong readback',
        );
      }
      if (_detailGeneration == detailGen &&
          (selectedId == null || selectedId == targetId)) {
        _selectedUser = detail;
      }
      _users = _users
          .map((u) => u.id == targetId ? detail.summary : u)
          .where(
            (u) =>
                (_roleFilter == null || u.role == _roleFilter) &&
                (_stateFilter == null || u.state == _stateFilter),
          )
          .toList(growable: false);
      _readbackNeeded = false;
      if (op.isCompleted) {
        _pendingMutationArgs = null;
        _reconcileArgs = null;
      } else if (_reconcileArgs != null) {
        // A received reconcile receipt ends that attempt; the next deliberate
        // retry can start a new one. Lost responses retain the frozen identity.
        _reconcileArgs = null;
      }
      return true;
    } on AdminFailure catch (f) {
      if (!_isCurrent(context)) return false;
      _fail(f);
      if (f.code == 'revision_conflict' ||
          f.code == 'revision_mismatch' ||
          !f.outcomeUncertain &&
              _pendingOperation == null &&
              f.code != 'network_error' &&
              f.code != 'upstream_unavailable' &&
              f.code != 'invalid_response') {
        _pendingMutationArgs = null;
        _pendingOperation = null;
        _reconcileArgs = null;
        if ((f.code == 'revision_conflict' || f.code == 'revision_mismatch') &&
            _isCurrent(context)) {
          // Preserve the reason in the dialog; refresh requires another explicit confirmation.
          await selectUser(args['targetId'] as String);
          if (_isCurrent(context)) _error = f;
        }
      }
      return false;
    } catch (e) {
      if (!_isCurrent(context)) return false;
      _error = AdminFailure(code: 'unknown', message: e.toString());
      return false;
    } finally {
      if (_isCurrent(context)) {
        _isMutating = false;
        notifyListeners();
      }
    }
  }

  void _checkOperation(AccountOperation op, Map<String, dynamic> args) {
    if (op.targetId != args['targetId'] ||
        op.action != args['action'] ||
        op.targetRevision != (args['expectedRevision'] as int) + 1) {
      throw const AdminFailure(
        code: 'invalid_response',
        outcomeUncertain: true,
        message: 'Wrong operation acknowledgement',
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    authProvider.removeListener(_handleAuthChange);
    super.dispose();
  }
}
