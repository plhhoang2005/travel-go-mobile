// Publication provider for managing catalogue release preview and confirmation state.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/services/admin_publication_service.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

class AdminPublicationProvider extends ChangeNotifier {
  final AdminPublicationService service;
  final AuthProvider authProvider;

  AdminPublicationProvider({
    required this.service,
    required this.authProvider,
  }) {
    _currentAuthEpoch = authProvider.authEpoch;
    _currentOwnerId = authProvider.currentUser?.id;
    _currentRole = authProvider.currentUser?.role.name;
    authProvider.addListener(_handleAuthChange);
  }

  String? _currentOwnerId;
  String? _currentRole;
  int _generation = 0;
  int? _currentAuthEpoch;
  String? _previewRequestId;
  int? _previewRevision;
  bool _disposed = false;

  PublicationPreview? _preview;
  PublicationOperation? _operation;
  String? _currentPublishRequestId;
  bool _isLoadingPreview = false;
  bool _isPublishing = false;
  AdminFailure? _error;

  PublicationPreview? get preview => _preview;
  PublicationOperation? get operation => _operation;
  bool get isLoadingPreview => _isLoadingPreview;
  bool get isPublishing => _isPublishing;
  AdminFailure? get error => _error;
  bool get hasBlockers => _preview?.hasBlockers ?? false;

  void _finishRejectedPublication(AdminFailure failure) {
    // The server has rejected this attempt. Fence any outstanding outcome read,
    // retain the error, and require a fresh preview before another publication.
    _generation++;
    _previewRequestId = null;
    _previewRevision = null;
    _preview = null;
    _operation = null;
    _currentPublishRequestId = null;
    _isLoadingPreview = false;
    _isPublishing = false;
    _error = failure;
    if (!_disposed) notifyListeners();
  }

  void _handleAuthChange() {
    final newOwnerId = authProvider.currentUser?.id;
    final newRole = authProvider.currentUser?.role.name;

    if (newOwnerId != _currentOwnerId || newRole != _currentRole ||
        _currentAuthEpoch != authProvider.authEpoch) {
      _currentAuthEpoch = authProvider.authEpoch;
      _currentOwnerId = newOwnerId;
      _currentRole = newRole;
      invalidate();
    }
  }

  void invalidate() {
    _generation++;
    _preview = null;
    _previewRequestId = null;
    _previewRevision = null;
    _operation = null;
    _currentPublishRequestId = null;
    _isLoadingPreview = false;
    _isPublishing = false;
    _error = null;
    if (!_disposed) notifyListeners();
  }

  static String _mintRequestId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> loadPreview(int revision) async {
    if (_isPublishing || _currentPublishRequestId != null) return;
    if (_previewRevision != revision) {
      _previewRequestId = null;
      _preview = null;
      _operation = null;
    }
    _previewRevision = revision;
    _previewRequestId ??= _mintRequestId();
    final gen = ++_generation;
    _isLoadingPreview = true;
    _error = null;
    notifyListeners();

    try {
      final p = await service.preview(requestId: _previewRequestId!, draftRevision: revision);
      if (gen != _generation || _disposed) return;
      _preview = p;
    } on AdminFailure catch (f) {
      if (gen != _generation || _disposed) return;
      _error = f;
    } catch (e) {
      if (gen != _generation || _disposed) return;
      _error = AdminFailure(code: 'unknown', message: e.toString());
    } finally {
      if (gen == _generation && !_disposed) {
        _isLoadingPreview = false;
        notifyListeners();
      }
    }
  }

  Future<bool> confirmPublish() async {
    if (_isPublishing) return false;
    if (_preview == null || hasBlockers || _isLoadingPreview) return false;
    if (_operation?.isCompleted == true) return true;
    final gen = _generation;
    final frozenPreview = _preview!;

    _isPublishing = true;
    _error = null;
    notifyListeners();

    // Preserve requestId across retries of the exact same preview
    _currentPublishRequestId ??= _mintRequestId();

    try {
      final op = await service.publish(
        requestId: _currentPublishRequestId!,
        preview: frozenPreview,
        expectedDraftRevision: frozenPreview.sourceRevision,
        expectedActiveVersion: frozenPreview.expectedActiveVersion,
      );

      if (gen != _generation || _disposed) return false;
      if (op.isConflict) {
        _finishRejectedPublication(const AdminFailure(
          code: 'conflict',
          message: 'Danh mục đã thay đổi. Hãy tải lại bản xem trước.',
        ));
        return false;
      }
      _operation = op;
      if (op.isCompleted) {
        _currentPublishRequestId = null; // Clear on success
      }
      return op.isCompleted;
    } on AdminFailure catch (f) {
      if (gen != _generation || _disposed) return false;
      _error = f;
      if (!f.outcomeUncertain) _finishRejectedPublication(f);
      return false;
    } catch (e) {
      if (gen != _generation || _disposed) return false;
      _error = AdminFailure(code: 'unknown', message: e.toString());
      return false;
    } finally {
      if (gen == _generation && !_disposed) {
        _isPublishing = false;
        notifyListeners();
      }
    }
  }

  Future<bool> checkOutcome() async {
    final opId = _operation?.id;
    if (opId == null) return false;
    final gen = _generation;

    try {
      final op = await service.operation(opId);
      if (gen != _generation || _disposed) return false;
      if (op.isConflict) {
        _finishRejectedPublication(const AdminFailure(
          code: 'conflict',
          message: 'Danh mục đã thay đổi. Hãy tải lại bản xem trước.',
        ));
        return false;
      }
      _operation = op;
      if (op.isCompleted) _currentPublishRequestId = null;
      notifyListeners();
      return op.isCompleted;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    authProvider.removeListener(_handleAuthChange);
    super.dispose();
  }
}
