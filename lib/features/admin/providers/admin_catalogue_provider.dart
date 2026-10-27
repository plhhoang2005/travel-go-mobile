// State management for TravelGO catalogue administration and draft editing.
// Strict RAM-only draft state; validated against A5 command contracts.
// Auto-chains save draft -> preview -> publish for customer catalogue visibility (D4).

import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/admin/models/admin_account_models.dart';
import 'package:travelgo_mobile/features/admin/models/admin_catalogue_models.dart';
import 'package:travelgo_mobile/features/admin/services/admin_catalogue_service.dart';
import 'package:travelgo_mobile/features/admin/services/admin_publication_service.dart';
import 'package:travelgo_mobile/features/auth/providers/auth_provider.dart';

enum AdminCatalogueSavePhase {
  idle,
  savingDraft,
  publishing,
  published,
  savedNotPublished,
}

class AdminCatalogueProvider extends ChangeNotifier {
  final AdminCatalogueService service;
  final AdminPublicationService publicationService;
  final AuthProvider authProvider;
  final Future<void> Function(PublicationOperation operation)? onPublished;

  String? _currentOwnerId;
  String? _currentRole;
  bool _disposed = false;
  int? _currentAuthEpoch;

  AdminCatalogueSnapshot? _snapshot;
  bool _isLoading = false;
  bool _isSaving = false;
  AdminFailure? _error;
  String? _lastErrorMessage;
  AdminCatalogueSavePhase _savePhase = AdminCatalogueSavePhase.idle;
  int? _savedRevision;

  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  Map<String, dynamic>? _pendingCommandArgs;
  String? _commandFingerprint;
  String? _previewRequestId;
  String? _publishRequestId;
  PublicationPreview? _publicationPreview;
  PublicationOperation? _publicationOperation;
  bool _outcomeUncertain = false;

  void _clearPublicationAttempt() {
    _previewRequestId = null;
    _publishRequestId = null;
    _publicationPreview = null;
    _publicationOperation = null;
  }

  AdminCatalogueProvider({
    required this.service,
    required this.publicationService,
    required this.authProvider,
    this.onPublished,
  }) {
    _currentAuthEpoch = authProvider.authEpoch;
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
  String? get lastErrorMessage => _lastErrorMessage;
  AdminCatalogueSavePhase get savePhase => _savePhase;
  int? get savedRevision => _savedRevision;

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
    _loadGeneration++;
    _mutationGeneration++;
    _snapshot = null;
    _pendingCommandArgs = null;
    _commandFingerprint = null;
    _outcomeUncertain = false;
    _clearPublicationAttempt();
    _savedRevision = null;
    _savePhase = AdminCatalogueSavePhase.idle;
    _error = null;
    _lastErrorMessage = null;
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
    if (_isSaving) return Future.value(false);
    final fingerprint = jsonEncode({'command': command, 'reason': reason});
    if (_outcomeUncertain) {
      if (_commandFingerprint == fingerprint) return _executePendingCommand();
      _error = const AdminFailure(code: 'publication_pending',
          message: 'Cần xác nhận kết quả lần lưu trước trước khi gửi thay đổi khác');
      _lastErrorMessage = _error!.message;
      notifyListeners();
      return Future.value(false);
    }
    _clearPublicationAttempt();
    _commandFingerprint = fingerprint;
    final reqId = _mintRequestId();
    _pendingCommandArgs = {
      'requestId': reqId,
      'expectedRevision': currentRevision,
      'command': jsonDecode(jsonEncode(command)) as Map<String, dynamic>,
      'reason': reason,
    };
    _savedRevision = null;
    return _executePendingCommand();
  }

  Future<bool> retrySave() {
    if (_pendingCommandArgs == null && _savedRevision == null) return Future.value(false);
    return _executePendingCommand();
  }

  Future<bool> _executePendingCommand() async {
    if (_isSaving) return false;
    final args = _pendingCommandArgs;
    if (args == null && _savedRevision == null) return false;

    _isSaving = true;
    _error = null;
    _lastErrorMessage = null;
    final int gen = ++_mutationGeneration;

    try {
      // Step 1: Save draft command (if not already acknowledged in a previous attempt)
      int targetRevision;
      if (_savedRevision != null) {
        targetRevision = _savedRevision!;
      } else {
        _savePhase = AdminCatalogueSavePhase.savingDraft;
        notifyListeners();

        final updatedSnap = await service.command(
          requestId: args!['requestId'] as String,
          expectedRevision: args['expectedRevision'] as int,
          command: args['command'] as Map<String, Object?>,
          reason: args['reason'] as String,
        );

        if (gen != _mutationGeneration || _disposed) return false;
        _snapshot = updatedSnap;
        _savedRevision = updatedSnap.revision;
        targetRevision = updatedSnap.revision;
        // Draft acknowledged by server; clear pending command so retry won't duplicate command
        _pendingCommandArgs = null;
      }

      // Step 2: Create Preview for targetRevision
      _savePhase = AdminCatalogueSavePhase.publishing;
      notifyListeners();

      _previewRequestId ??= _mintRequestId();
      final preview = _publicationPreview ?? await publicationService.preview(
        requestId: _previewRequestId!,
        draftRevision: targetRevision,
      );
      if (gen != _mutationGeneration || _disposed) return false;
      _publicationPreview = preview;

      if (preview.hasBlockers) {
        _clearPublicationAttempt();
        _savePhase = AdminCatalogueSavePhase.savedNotPublished;
        final blockerMsgs = preview.blockers.map((b) => b.message).join('; ');
        _lastErrorMessage = 'Đã lưu, chưa xuất bản: $blockerMsgs';
        _error = AdminFailure(code: 'preview_blockers', message: _lastErrorMessage!);
        return false;
      }

      if (preview.sourceRevision != targetRevision) {
        _clearPublicationAttempt();
        _savePhase = AdminCatalogueSavePhase.savedNotPublished;
        _lastErrorMessage = 'Đã lưu, chưa xuất bản: revision không khớp';
        _error = AdminFailure(code: 'revision_mismatch', message: _lastErrorMessage!);
        return false;
      }

      // Step 3: Publish
      _publishRequestId ??= _mintRequestId();
      _outcomeUncertain = true;
      PublicationOperation? operation;
      if (_publicationOperation != null) {
        operation = await publicationService.operation(_publicationOperation!.id);
        if (gen != _mutationGeneration || _disposed) return false;
      }
      if (operation?.isCompleted != true) {
        operation = await publicationService.publish(
        requestId: _publishRequestId!,
        preview: preview,
        expectedDraftRevision: targetRevision,
        expectedActiveVersion: preview.expectedActiveVersion,
        );
      }
      if (gen != _mutationGeneration || _disposed) return false;
      _publicationOperation = operation;

      if (operation!.isCompleted && operation.sourceRevision == targetRevision && operation.version != null) {
        _savePhase = AdminCatalogueSavePhase.published;
        _outcomeUncertain = false;
        _clearPublicationAttempt();
        _savedRevision = null; // Successfully published; clear saved revision
        _lastErrorMessage = null;

        try {
          if (onPublished != null) {
            await onPublished!(operation);
          }
        } catch (e) {
          // Local refresh error must not fail publication that already completed on server
          if (gen != _mutationGeneration || _disposed) return false;
          _lastErrorMessage = 'Đã lưu và xuất bản, nhưng đồng bộ nội bộ gặp lỗi: $e';
        }
        return gen == _mutationGeneration && !_disposed;
      } else {
        if (operation.isConflict) {
          _outcomeUncertain = false;
          _clearPublicationAttempt();
        }
        _savePhase = AdminCatalogueSavePhase.savedNotPublished;
        _lastErrorMessage = 'Đã lưu, xuất bản chưa hoàn tất (${operation.state})';
        _error = AdminFailure(code: 'publish_not_completed', message: _lastErrorMessage!);
        return false;
      }
    } on AdminFailure catch (f) {
      if (gen != _mutationGeneration || _disposed) return false;
      _error = f;
      _outcomeUncertain = f.outcomeUncertain;
      if (!f.outcomeUncertain) {
        _clearPublicationAttempt();
        _pendingCommandArgs = null;
      }
      if (_savedRevision != null) {
        _savePhase = AdminCatalogueSavePhase.savedNotPublished;
        _lastErrorMessage = 'Đã lưu, chưa xuất bản: ${f.message}';
      } else {
        _savePhase = AdminCatalogueSavePhase.idle;
        _lastErrorMessage = f.message;
      }
      return false;
    } catch (e) {
      if (gen != _mutationGeneration || _disposed) return false;
      _outcomeUncertain = true;
      final f = AdminFailure(code: 'unknown', message: e.toString(), outcomeUncertain: true);
      _error = f;
      if (_savedRevision != null) {
        _savePhase = AdminCatalogueSavePhase.savedNotPublished;
        _lastErrorMessage = 'Đã lưu, chưa xuất bản: ${f.message}';
      } else {
        _savePhase = AdminCatalogueSavePhase.idle;
        _lastErrorMessage = f.message;
      }
      return false;
    } finally {
      if (gen == _mutationGeneration && !_disposed) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _mutationGeneration++;
    _loadGeneration++;
    authProvider.removeListener(_handleAuthChange);
    super.dispose();
  }
}
