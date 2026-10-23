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

  AdminAccountProvider({
    required this.service,
    required this.authProvider,
  }) {
    _currentOwnerId = authProvider.currentUser?.id;
    _currentRole = authProvider.currentUser?.role.name;
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

    if (newOwnerId != _currentOwnerId || newRole != _currentRole) {
      _currentOwnerId = newOwnerId;
      _currentRole = newRole;
      invalidate();
    }
  }

  void invalidate() {
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
    _error = null;

    _isLoadingUsers = false;
    _isLoadingDetail = false;
    _isLoadingDashboard = false;
    _isMutating = false;

    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> enter() async {
    _error = null;
    try {
      final access = await service.access();
      _hasAdminAccess = access.allowed && access.role == 'admin';
    } on AdminFailure catch (f) {
      _hasAdminAccess = false;
      _error = f;
    } catch (e) {
      _hasAdminAccess = false;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  void setFilter({String? query, String? role, String? state}) {
    var changed = false;
    if (query != null && query != _query) {
      _query = query;
      changed = true;
    }
    if (role != _roleFilter) {
      _roleFilter = role;
      changed = true;
    }
    if (state != _stateFilter) {
      _stateFilter = state;
      changed = true;
    }

    if (changed) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        loadUsers(nextPage: false);
      });
    }
  }

  Future<void> loadUsers({bool nextPage = false}) async {
    if (_isLoadingUsers && !nextPage) return;
    if (nextPage && _nextCursor == null) return;

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
      if (gen != _usersGeneration || _disposed) return;

      if (nextPage) {
        _users = [..._users, ...page.items];
      } else {
        _users = page.items;
      }
      _nextCursor = page.nextCursor;
    } on AdminFailure catch (f) {
      if (gen != _usersGeneration || _disposed) return;
      _error = f;
    } catch (e) {
      if (gen != _usersGeneration || _disposed) return;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (gen == _usersGeneration && !_disposed) {
        _isLoadingUsers = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectUser(String id) async {
    final gen = ++_detailGeneration;
    _selectedUser = null;
    _isLoadingDetail = true;
    _error = null;
    notifyListeners();

    try {
      final detail = await service.getUser(id);
      if (gen != _detailGeneration || _disposed) return;
      _selectedUser = detail;
    } on AdminFailure catch (f) {
      if (gen != _detailGeneration || _disposed) return;
      _error = f;
    } catch (e) {
      if (gen != _detailGeneration || _disposed) return;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (gen == _detailGeneration && !_disposed) {
        _isLoadingDetail = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadDashboard(int days) async {
    final gen = ++_dashboardGeneration;
    _isLoadingDashboard = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await service.dashboard(days: days);
      if (gen != _dashboardGeneration || _disposed) return;
      _dashboardSnapshot = snapshot;
    } on AdminFailure catch (f) {
      if (gen != _dashboardGeneration || _disposed) return;
      _error = f;
    } catch (e) {
      if (gen != _dashboardGeneration || _disposed) return;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (gen == _dashboardGeneration && !_disposed) {
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
    if (_isMutating) return false;

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
    return _dispatchMutation(_pendingMutationArgs!);
  }

  Future<bool> _dispatchMutation(Map<String, dynamic> args) async {
    _isMutating = true;
    _error = null;
    notifyListeners();

    try {
      final op = await service.mutate(
        requestId: args['requestId'] as String,
        targetId: args['targetId'] as String,
        expectedRevision: args['expectedRevision'] as int,
        action: args['action'] as String,
        reason: args['reason'] as String,
      );

      _pendingOperation = op;

      // Update user state in memory if matches
      final targetId = args['targetId'] as String;
      final action = args['action'] as String;
      final nextState = action == 'lock'
          ? 'locked'
          : (action == 'unlock' ? 'unlocking' : null);
      final nextRole = action == 'promote'
          ? 'admin'
          : (action == 'demote' ? 'customer' : null);

      if (_selectedUser != null && _selectedUser!.id == targetId) {
        _selectedUser = UserDetail(
          summary: UserSummary(
            id: _selectedUser!.id,
            fullName: _selectedUser!.fullName,
            email: _selectedUser!.email,
            role: nextRole ?? _selectedUser!.role,
            state: nextState ?? _selectedUser!.state,
            revision: op.targetRevision,
            createdAt: _selectedUser!.createdAt,
            lastSignInAt: _selectedUser!.lastSignInAt,
            authSynced: op.authSynced,
          ),
          audit: _selectedUser!.audit,
        );
      }

      // Update user in list
      _users = _users.map((u) {
        if (u.id == targetId) {
          return UserSummary(
            id: u.id,
            fullName: u.fullName,
            email: u.email,
            role: nextRole ?? u.role,
            state: nextState ?? u.state,
            revision: op.targetRevision,
            createdAt: u.createdAt,
            lastSignInAt: u.lastSignInAt,
            authSynced: op.authSynced,
          );
        }
        return u;
      }).toList(growable: false);

      return true;
    } on AdminFailure catch (f) {
      _error = f;
      return false;
    } catch (e) {
      _error = AdminFailure(code: 'unknown', message: e.toString());
      return false;
    } finally {
      _isMutating = false;
      if (!_disposed) notifyListeners();
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
