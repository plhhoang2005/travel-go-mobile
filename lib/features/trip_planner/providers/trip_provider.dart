import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../trips/models/local_trip_records.dart';
import '../../trips/models/trip_payload_codec.dart';
import '../../trips/services/local_trip_store.dart';
import '../models/trip_request.dart';
import '../models/trip_response.dart';
import '../services/trip_api_service.dart';

class _PlannerWorkspace {
  final PlanTripRequest request;
  final PlanTripResponse? response;
  final TripMetadataV1 metadata;
  final bool hasInput, restored, activity;
  final String? draftId, savedDigest;
  final int? revision;
  const _PlannerWorkspace(
    this.request,
    this.response,
    this.metadata,
    this.hasInput,
    this.restored,
    this.activity,
    this.draftId,
    this.revision,
    this.savedDigest,
  );
}

class TripProvider extends ChangeNotifier {
  final TripApiService _apiService;
  final Future<LocalTripStore> Function()? localStoreLoader;
  final String Function() _draftIdFactory;
  TripProvider({
    TripApiService? apiService,
    this.localStoreLoader,
    String Function()? draftIdFactory,
  }) : _apiService = apiService ?? TripApiService(),
       _draftIdFactory = draftIdFactory ?? (() => const Uuid().v4());

  PlanTripRequest _currentRequest = TripPayloadCodec.deepFreezeRequest(
    PlanTripRequest.presetMinh(),
  );
  PlanTripResponse? _currentResponse;
  TripMetadataV1 _metadata = TripMetadataV1();
  bool _hasInput = true,
      _restored = false,
      _activity = false,
      _isLoading = false;
  bool _isBackendOnline = false,
      _draftLoading = false,
      _disposed = false,
      _notifyScheduled = false;
  String? _errorMessage, _draftError, _draftId, _savedDigest;
  int? _draftRevision;
  int _generation = 0, _planOperation = 0, _loadOperation = 0, _authEpoch = 0;
  bool _guest = true, _demo = false;
  String? _owner;
  Future<GuestDraftRevisionRecord?>? _saveFuture;
  _PlannerWorkspace? _guestCheckpoint;

  PlanTripRequest get currentRequest => _currentRequest;
  PlanTripResponse? get currentResponse => _currentResponse;
  TripMetadataV1 get currentMetadata => _metadata;
  bool get hasSelectedDestination => _metadata.destinationId != null;
  bool get isAccountWorkspace => !_guest && !_demo && _owner != null;
  bool get canReplaceWorkspace =>
      !_disposed &&
      !_draftLoading &&
      _saveFuture == null &&
      !_demo &&
      (_guest || _owner != null);
  bool get isLoading => _isLoading;
  bool get isBackendOnline => _isBackendOnline;
  String? get errorMessage => _errorMessage;
  String? get activeDraftId => _draftId;
  int? get activeDraftRevision => _draftRevision;
  int get workspaceGeneration => _generation;
  bool get hasPlannerInput => _hasInput;
  bool get isRestoredLocalDraft => _restored;
  bool get canPersistGuestDraft =>
      !_disposed &&
      _guest &&
      !_demo &&
      _owner == null &&
      localStoreLoader != null;
  bool get isSavingDraft => _saveFuture != null;
  bool get isLoadingDraft => _draftLoading;
  String? get draftErrorMessage => _draftError;
  bool get isDraftDirty {
    if (!_activity) return false;
    try {
      return TripPayloadCodec.computeDigest(_payload()) != _savedDigest;
    } catch (_) {
      return true;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _deferNotify() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      _notify();
    });
  }

  void _invalidate() {
    _generation++;
    _planOperation++;
    _loadOperation++;
    _isLoading = false;
    _draftLoading = false;
    _errorMessage = null;
    _draftError = null;
  }

  bool _current(int generation) => !_disposed && generation == _generation;
  _PlannerWorkspace _capture() => _PlannerWorkspace(
    _currentRequest,
    _currentResponse,
    _metadata,
    _hasInput,
    _restored,
    _activity,
    _draftId,
    _draftRevision,
    _savedDigest,
  );
  void _restore(_PlannerWorkspace workspace) {
    _currentRequest = workspace.request;
    _currentResponse = workspace.response;
    _metadata = workspace.metadata;
    _hasInput = workspace.hasInput;
    _restored = workspace.restored;
    _activity = workspace.activity;
    _draftId = workspace.draftId;
    _draftRevision = workspace.revision;
    _savedDigest = workspace.savedDigest;
  }

  /// Synchronous ProxyProvider fencing; notify only after the build stack.
  void setPlannerContext({
    required bool isGuest,
    required bool isDemo,
    required String? ownerId,
    required int authEpoch,
  }) {
    if (_disposed ||
        (_guest == isGuest &&
            _demo == isDemo &&
            _owner == ownerId &&
            _authEpoch == authEpoch)) {
      return;
    }
    final changedIdentity =
        _guest != isGuest || _demo != isDemo || _owner != ownerId;
    if (_guest && !_demo && _owner == null) {
      _guestCheckpoint = _capture();
    }
    _invalidate();
    if (changedIdentity) {
      final checkpoint = _guestCheckpoint;
      if (checkpoint != null) {
        _restore(checkpoint);
      } else {
        _resetWorkspace();
      }
    }
    _guest = isGuest;
    _demo = isDemo;
    _owner = ownerId;
    _authEpoch = authEpoch;
    _deferNotify();
  }

  Future<void> init() async {
    if (_disposed || hasSelectedDestination) return;
    final generation = _generation;
    try {
      final online = await _apiService.checkHealth();
      if (_current(generation)) {
        _isBackendOnline = online;
        _notify();
      }
    } catch (_) {
      if (_current(generation)) {
        _isBackendOnline = false;
        _notify();
      }
    }
  }

  void updateRequest(PlanTripRequest newRequest) {
    if (_disposed) return;
    final frozen = TripPayloadCodec.deepFreezeRequest(newRequest);
    if (_hasInput &&
        jsonEncode(frozen.toJson()) == jsonEncode(_currentRequest.toJson())) {
      return;
    }
    _invalidate();
    _currentRequest = frozen;
    _hasInput = true;
    _currentResponse = null;
    _restored = false;
    _activity = true;
    _notify();
  }

  void applyPreset(int presetId) {
    if (presetId == 1) {
      updateRequest(PlanTripRequest.presetMinh());
    } else if (presetId == 2) {
      updateRequest(PlanTripRequest.presetPhuQuoc());
    } else if (presetId == 3) {
      updateRequest(PlanTripRequest.presetVungTau());
    }
  }

  Future<bool> submitPlan() async {
    // The current engine chooses its own destination. Never send a selected
    // destination workspace to it, including restored drafts with saved results.
    if (_disposed || !_hasInput || hasSelectedDestination) return false;
    _invalidate();
    final generation = _generation;
    final operation = _planOperation;
    final request = TripPayloadCodec.deepFreezeRequest(_currentRequest);
    _currentResponse = null;
    _restored = false;
    _activity = true;
    _isLoading = true;
    _notify();
    try {
      final response = await _apiService.planTrip(request);
      if (!_current(generation) || operation != _planOperation) return false;
      _currentResponse = TripPayloadCodec.deepFreezePlan(response);
      return true;
    } catch (_) {
      if (_current(generation) && operation == _planOperation) {
        _errorMessage = 'Không thể nhận kế hoạch từ máy chủ.';
      }
      return false;
    } finally {
      if (_current(generation) && operation == _planOperation) {
        _isLoading = false;
        _notify();
      }
    }
  }

  CanonicalTripPayloadV1 _payload({TripMetadataV1? metadata}) =>
      CanonicalTripPayloadV1(
        metadata: metadata ?? _metadata,
        request: _hasInput ? _currentRequest : null,
        plan: _currentResponse,
      );
  Future<GuestDraftRevisionRecord?> saveGuestDraft({String? title}) {
    if (!canPersistGuestDraft) {
      if (!_disposed) {
        _draftError = 'Chỉ Guest có thể lưu bản nháp trên máy.';
        _notify();
      }
      return Future.value(null);
    }
    final pending = _saveFuture;
    if (pending != null) return pending;
    _draftError = null;
    _activity = true;
    final generation = _generation;
    final id = _draftId ??= _draftIdFactory();
    final editedTitle = title?.trim();
    final metadata = editedTitle == null || editedTitle.isEmpty
        ? _metadata
        : TripMetadataV1(
            title: editedTitle,
            destinationId: _metadata.destinationId,
            destinationName: _metadata.destinationName,
            startDate: _metadata.startDate,
            endDate: _metadata.endDate,
            timezone: _metadata.timezone,
          );
    final future = _save(generation, id, metadata);
    _saveFuture = future;
    _notify();
    unawaited(
      future.then((_) {
        if (identical(_saveFuture, future)) {
          _saveFuture = null;
          _notify();
        }
      }),
    );
    return future;
  }

  Future<GuestDraftRevisionRecord?> _save(
    int generation,
    String id,
    TripMetadataV1 metadata,
  ) async {
    try {
      final payload = _payload(metadata: metadata);
      final store = await localStoreLoader!();
      if (!_current(generation) || !canPersistGuestDraft) return null;
      final row = await store.saveDraftRevision(draftId: id, payload: payload);
      if (!_current(generation) || !canPersistGuestDraft) return null;
      _metadata = metadata;
      _draftId = row.draftId;
      _draftRevision = row.revision;
      _savedDigest = row.digest;
      _notify();
      return row;
    } catch (_) {
      if (_current(generation)) {
        _draftError =
            'Không thể lưu xuống máy; nội dung đang nhập vẫn được giữ.';
        _notify();
      }
      return null;
    }
  }

  Future<List<GuestDraftSummaryRecord>> listGuestDrafts() async {
    if (!canPersistGuestDraft) return const [];
    final generation = _generation;
    final operation = ++_loadOperation;
    _draftLoading = true;
    _draftError = null;
    _notify();
    try {
      final store = await localStoreLoader!();
      if (!_current(generation) || operation != _loadOperation) return const [];
      final rows = await store.listGuestDrafts();
      for (final row in rows) {
        final source = await store.getDraftRevision(
          draftId: row.draftId,
          revision: row.currentRevision,
          deviceScope: row.deviceScope,
        );
        if (source == null) {
          throw StateError('Listed revision is no longer available.');
        }
      }
      return _current(generation) && operation == _loadOperation
          ? rows
          : const [];
    } catch (_) {
      if (_current(generation) && operation == _loadOperation) {
        _draftError = 'Không thể đọc bản nháp an toàn.';
      }
      return const [];
    } finally {
      if (_current(generation) && operation == _loadOperation) {
        _draftLoading = false;
        _notify();
      }
    }
  }

  Future<bool> openGuestDraft({
    required String draftId,
    required int revision,
    required int expectedWorkspaceGeneration,
  }) async {
    if (!canPersistGuestDraft || expectedWorkspaceGeneration != _generation) {
      return false;
    }
    final generation = _generation;
    final operation = ++_loadOperation;
    _draftLoading = true;
    _draftError = null;
    _notify();
    try {
      final store = await localStoreLoader!();
      if (!_current(generation) || operation != _loadOperation) return false;
      final row = await store.getDraftRevision(
        draftId: draftId,
        revision: revision,
      );
      if (!_current(generation) || operation != _loadOperation) return false;
      if (row == null) throw StateError('Revision unavailable.');
      final payload = row.cachedPayload;
      _invalidate();
      _metadata = payload.metadata;
      _hasInput = payload.request != null;
      _currentRequest =
          payload.request ??
          TripPayloadCodec.deepFreezeRequest(PlanTripRequest.presetMinh());
      _currentResponse = payload.plan;
      _draftId = row.draftId;
      _draftRevision = row.revision;
      _savedDigest = row.digest;
      _restored = true;
      _activity = true;
      _notify();
      return true;
    } catch (_) {
      if (_current(generation) && operation == _loadOperation) {
        _draftError = 'Bản nháp không khả dụng hoặc dữ liệu không hợp lệ.';
      }
      return false;
    } finally {
      if (_current(generation) && operation == _loadOperation) {
        _draftLoading = false;
        _notify();
      }
    }
  }

  void _resetWorkspace() {
    _currentRequest = TripPayloadCodec.deepFreezeRequest(
      PlanTripRequest.presetMinh(),
    );
    _currentResponse = null;
    _metadata = TripMetadataV1();
    _hasInput = true;
    _restored = false;
    _activity = false;
    _draftId = null;
    _draftRevision = null;
    _savedDigest = null;
  }

  bool startNewGuestDraft({required int expectedWorkspaceGeneration}) {
    if (!canPersistGuestDraft || expectedWorkspaceGeneration != _generation) {
      return false;
    }
    _invalidate();
    _resetWorkspace();
    _notify();
    return true;
  }

  bool prepareDestinationWorkspace({
    required String destinationId,
    required String destinationName,
    required int expectedWorkspaceGeneration,
    bool replaceDirty = false,
  }) {
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(destinationId) ||
        destinationName.trim().isEmpty) {
      return false;
    }
    TripMetadataV1 metadata;
    try {
      metadata = TripMetadataV1(
        title: 'Chuyến đi $destinationName',
        destinationId: destinationId,
        destinationName: destinationName,
      );
    } on TripPayloadException {
      return false;
    }
    return _replaceWorkspace(
      metadata,
      expectedWorkspaceGeneration,
      replaceDirty,
    );
  }

  bool useSuggestedDestination({
    required int expectedWorkspaceGeneration,
    bool replaceDirty = false,
  }) => _replaceWorkspace(
    TripMetadataV1(),
    expectedWorkspaceGeneration,
    replaceDirty,
  );

  bool _replaceWorkspace(
    TripMetadataV1 metadata,
    int expectedGeneration,
    bool replaceDirty,
  ) {
    if (!canReplaceWorkspace ||
        expectedGeneration != _generation ||
        (isDraftDirty && !replaceDirty)) {
      return false;
    }
    final request = TripPayloadCodec.deepFreezeRequest(
      _hasInput ? _currentRequest : PlanTripRequest.presetMinh(),
    );
    _invalidate();
    _currentRequest = request;
    _metadata = metadata;
    _currentResponse = null;
    _draftId = null;
    _draftRevision = null;
    _savedDigest = null;
    _hasInput = true;
    _restored = false;
    _activity = true;
    _notify();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidate();
    super.dispose();
  }
}
