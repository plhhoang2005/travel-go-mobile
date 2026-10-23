// State management for TravelGO catalogue administration and draft editing.
// Strict RAM-only draft state; validated against A5 command contracts.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/services/admin_catalogue_service.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

class AdminCatalogueProvider extends ChangeNotifier {
  final AdminCatalogueService service;
  final AuthProvider authProvider;

  String? _currentOwnerId;
  String? _currentRole;
  bool _disposed = false;

  AdminCatalogueSnapshot? _snapshot;
  bool _isLoading = false;
  bool _isSaving = false;
  AdminFailure? _error;

  int _loadGeneration = 0;
  Map<String, dynamic>? _pendingCommandArgs;

  AdminCatalogueProvider({
    required this.service,
    required this.authProvider,
  }) {
    _currentOwnerId = authProvider.currentUser?.id;
    _currentRole = authProvider.currentUser?.role.name;
    authProvider.addListener(_handleAuthChange);
  }

  AdminCatalogueSnapshot? get snapshot => _snapshot;
  List<AdminDestinationDraft> get destinations => _snapshot?.destinations ?? const [];
  List<AdminPlaceDraft> get places => _snapshot?.places ?? const [];
  List<AdminDraftVersion> get history => _snapshot?.history ?? const [];
  int get currentRevision => _snapshot?.revision ?? 1;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  AdminFailure? get error => _error;

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
    _loadGeneration++;
    _snapshot = null;
    _pendingCommandArgs = null;
    _error = null;
    _isLoading = false;
    _isSaving = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    final gen = ++_loadGeneration;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snap = await service.read();
      if (gen != _loadGeneration || _disposed) return;
      _snapshot = snap;
    } on AdminFailure catch (f) {
      if (gen != _loadGeneration || _disposed) return;
      _error = f;
    } catch (e) {
      if (gen != _loadGeneration || _disposed) return;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (gen == _loadGeneration && !_disposed) {
        _isLoading = false;
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

  Future<bool> submitDestination(AdminDestinationDraft draft, String reason) {
    final cmd = draft.id == null ? draft.toCreateCommand() : draft.toUpdateCommand();
    return _dispatchCommand(cmd, reason);
  }

  Future<bool> submitPlace(AdminPlaceDraft draft, String reason) {
    final cmd = draft.id == null ? draft.toCreateCommand() : draft.toUpdateCommand();
    return _dispatchCommand(cmd, reason);
  }

  Future<bool> archiveDestination(String id, String reason) {
    final cmd = {
      'command': 'archiveDestination',
      'destinationId': id,
    };
    return _dispatchCommand(cmd, reason);
  }

  Future<bool> archivePlace(String id, String reason) {
    final cmd = {
      'command': 'archivePlace',
      'placeId': id,
    };
    return _dispatchCommand(cmd, reason);
  }

  Future<bool> restoreVersion(int revision, String reason) {
    final cmd = {
      'command': 'restoreVersion',
      'targetRevision': revision,
    };
    return _dispatchCommand(cmd, reason);
  }

  Future<bool> _dispatchCommand(Map<String, dynamic> command, String reason) {
    final reqId = _mintRequestId();
    _pendingCommandArgs = {
      'requestId': reqId,
      'expectedRevision': currentRevision,
      'command': command,
      'reason': reason,
    };
    return _executePendingCommand();
  }

  Future<bool> retrySave() {
    if (_pendingCommandArgs == null) return Future.value(false);
    return _executePendingCommand();
  }

  Future<bool> _executePendingCommand() async {
    if (_isSaving) return false;
    final args = _pendingCommandArgs;
    if (args == null) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final updatedSnap = await service.command(
        requestId: args['requestId'] as String,
        expectedRevision: args['expectedRevision'] as int,
        command: args['command'] as Map<String, Object?>,
        reason: args['reason'] as String,
      );

      _snapshot = updatedSnap;
      _pendingCommandArgs = null; // Cleared on successful acknowledgement
      return true;
    } on AdminFailure catch (f) {
      _error = f;
      return false;
    } catch (e) {
      _error = AdminFailure(code: 'unknown', message: e.toString());
      return false;
    } finally {
      _isSaving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    authProvider.removeListener(_handleAuthChange);
    super.dispose();
  }
}
