import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/local_trip_records.dart';
import '../models/saved_trip_model.dart';
import '../models/trip_payload_codec.dart';
import '../services/local_account_lifecycle_service.dart';
import '../services/local_trip_store.dart';
import '../services/trip_snapshot_service.dart';
import '../services/trips_service.dart';
import '../services/editable_trip_repository.dart';
import '../services/editable_trip_service.dart';
import '../models/editable_remote_records.dart';

enum AccountCacheState {
  idle,
  loading,
  online,
  offline,
  unavailable,
  blocked,
  error,
}

class SavedTripsProvider extends ChangeNotifier {
  final TripsService _service;
  final bool requiresLifecycle;
  LocalAccountLifecycleService? _lifecycle;
  LocalTripStore? _cacheStore;
  TripSnapshotService? _snapshotService;
  SessionHandle? _accountHandle;
  List<AccountTripSnapshotRecord> _accountSnapshots = [];
  AccountCacheState _cacheState = AccountCacheState.idle;
  String? _cacheErrorMessage;
  String? _cacheWriteMessage;

  EditableTripRepository? _editableRepository;
  List<OwnedTripSummary> _visibleTrips = [];
  OwnedTripCursor? _nextCursor;
  List<SavedTrip> _trips = [];
  bool _isLoading = false;
  String? _currentUserId;
  String? _errorMessage;
  int _sessionEpoch = 0;
  bool _isDisposed = false;
  String? _pendingFetchUserId;
  int? _pendingFetchEpoch;

  List<SavedTrip> get trips => List.unmodifiable(_trips);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentUserId => _currentUserId;
  int get sessionEpoch => _sessionEpoch;
  int get count => visibleTrips.length;
  bool get hasMoreTrips => _nextCursor != null;
  List<OwnedTripSummary> get visibleTrips {
    if (requiresLifecycle &&
        (_accountHandle == null || _lifecycle?.handle != _accountHandle)) {
      return const [];
    }
    return List.unmodifiable(
      _editableRepository == null ? _trips.map(_legacySummary) : _visibleTrips,
    );
  }

  static OwnedTripSummary _legacySummary(SavedTrip trip) => OwnedTripSummary(
    kind: OwnedTripKind.legacyV1,
    tripId: trip.id,
    ownerId: trip.userId,
    title: trip.title,
    destinationName: trip.destinationName,
    createdAt:
        trip.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    version: null,
  );
  static OwnedTripSummary _editableSummary(
    EditableHead head, {
    DateTime? createdAt,
  }) => OwnedTripSummary(
    kind: OwnedTripKind.editableV2,
    tripId: head.tripId,
    ownerId: head.ownerId,
    title: head.document.input.title,
    destinationName:
        head.document.input.destinationName ?? 'Chưa chọn điểm đến',
    // Epoch is an unknown-sort placeholder for cached entries, never a claimed creation date.
    createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    version: head.version,
  );
  void bindEditableRepository(EditableTripRepository repository) {
    if (_isDisposed || !requiresLifecycle) return;
    if (!identical(repository.lifecycle, _lifecycle) ||
        !identical(repository.store, _cacheStore)) {
      throw StateError('Editable repository does not match account storage.');
    }
    _editableRepository = repository;
    _visibleTrips = [];
    _nextCursor = null;
    _notifyDeferred();
  }

  Future<void> loadMoreTrips() async {
    if (_isLoading || _nextCursor == null || _editableRepository == null) {
      return;
    }
    await _loadMixedTrips(_currentUserId, more: true);
  }

  List<AccountTripSnapshotRecord> get accountSnapshots =>
      List.unmodifiable(_accountSnapshots);
  AccountCacheState get cacheState => _cacheState;
  String? get cacheErrorMessage => _cacheErrorMessage;
  String? get cacheWriteMessage => _cacheWriteMessage;

  SavedTripsProvider({TripsService? service, this.requiresLifecycle = false})
    : _service = service ?? TripsService();

  void bindAccount({
    required LocalAccountLifecycleService lifecycle,
    required LocalTripStore store,
    required TripSnapshotService snapshots,
    required SessionHandle handle,
  }) {
    if (_isDisposed || !requiresLifecycle) return;
    _sessionEpoch++;
    _lifecycle = lifecycle;
    _cacheStore = store;
    _snapshotService = snapshots;
    _accountHandle = handle;
    _currentUserId = handle.ownerId;
    _trips = [];
    _visibleTrips = [];
    _nextCursor = null;
    _accountSnapshots = [];
    _cacheState = AccountCacheState.loading;
    _cacheErrorMessage = null;
    _cacheWriteMessage = null;
    _pendingFetchUserId = handle.ownerId;
    _pendingFetchEpoch = _sessionEpoch;
    _notifyDeferred();
  }

  void unbindAccount() {
    if (_isDisposed) return;
    _accountHandle = null;
    _lifecycle = null;
    _cacheStore = null;
    _snapshotService = null;
    clearLocal();
  }

  void _notifyDeferred() {
    if (_isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) notifyListeners();
    });
  }

  List<SavedTrip> get upcomingTrips {
    final now = DateTime.now();
    return _trips
        .where(
          (t) =>
              t.startDate == null ||
              t.startDate!.isAfter(now.subtract(const Duration(days: 1))),
        )
        .toList();
  }

  Future<void> loadTrips(String? userId) async {
    if (_isDisposed) return;
    if (requiresLifecycle) {
      await _loadOwnedTrips(userId);
      return;
    }
    _sessionEpoch++;
    final targetEpoch = _sessionEpoch;

    if (userId == null || userId.isEmpty) {
      _trips = [];
      _currentUserId = null;
      _errorMessage = null;
      _isLoading = false;
      _pendingFetchUserId = null;
      _pendingFetchEpoch = null;
      if (!_isDisposed) notifyListeners();
      return;
    }

    final isNewUser = _currentUserId != userId;
    if (isNewUser) {
      _trips = [];
      _errorMessage = null;
    }

    _currentUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      final fetched = await _service.fetchTrips(userId);
      // Drop late responses if disposed, epoch changed, or user changed
      if (_isDisposed ||
          _sessionEpoch != targetEpoch ||
          _currentUserId != userId) {
        return;
      }
      _trips = fetched;
      _errorMessage = null;
    } catch (e) {
      if (_isDisposed ||
          _sessionEpoch != targetEpoch ||
          _currentUserId != userId) {
        return;
      }
      _errorMessage = 'Lỗi tải danh sách chuyến đi: ${e.toString()}';
    } finally {
      if (!_isDisposed &&
          _sessionEpoch == targetEpoch &&
          _currentUserId == userId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _currentAccount(String owner, int epoch, AccountSessionProof proof) =>
      !_isDisposed &&
      _sessionEpoch == epoch &&
      _currentUserId == owner &&
      _accountHandle?.ownerId == owner &&
      _lifecycle?.isCurrentProof(proof) == true;

  Future<void> _tryMixedOffline(
    LocalTripStore store,
    SessionHandle handle,
    String owner,
    int epoch,
    AccountSessionProof proof,
  ) async {
    try {
      await _showOwnedOffline(store, handle, owner, epoch, proof);
    } catch (_) {
      if (!_currentAccount(owner, epoch, proof)) return;
      _visibleTrips = [];
      _trips = [];
      _accountSnapshots = [];
      _nextCursor = null;
      _cacheState = AccountCacheState.error;
      _cacheErrorMessage = 'Cache trên máy chưa thể đọc an toàn.';
    }
  }

  void _sortVisible() => _visibleTrips.sort((a, b) {
    final time = b.createdAt.compareTo(a.createdAt);
    return time != 0 ? time : b.tripId.compareTo(a.tripId);
  });
  Future<void> _loadMixedTrips(String? owner, {bool more = false}) async {
    final lifecycle = _lifecycle,
        store = _cacheStore,
        adapter = _snapshotService;
    final handle = _accountHandle, repository = _editableRepository;
    if (handle != null && owner != handle.ownerId) return;
    if (owner == null ||
        lifecycle == null ||
        store == null ||
        adapter == null ||
        handle == null ||
        repository == null) {
      clearLocal();
      return;
    }
    AccountSessionProof proof;
    VoidCallback finish;
    try {
      proof = lifecycle.captureProof();
      finish = lifecycle.beginAccountOperation(proof);
    } catch (_) {
      clearLocal();
      return;
    }
    final epoch = ++_sessionEpoch;
    _isLoading = true;
    _cacheState = AccountCacheState.loading;
    _cacheErrorMessage = null;
    _errorMessage = null;
    _notifyDeferred();
    try {
      final page = await repository.listOwned(
        cursor: more ? _nextCursor : null,
      );
      if (!_currentAccount(owner, epoch, proof)) return;
      if (page.items.any((t) => t.ownerId != owner) ||
          page.items.map((t) => t.tripId).toSet().length != page.items.length) {
        throw const SnapshotRejectedException('Invalid mixed list identity.');
      }
      final summaries = <String, OwnedTripSummary>{
        if (more)
          for (final row in _visibleTrips) row.tripId: row,
        for (final row in page.items) row.tripId: row,
      };
      final batch = await adapter.fetchLegacySnapshots(
        proof: proof,
        tripIds: page.items
            .where((t) => t.kind == OwnedTripKind.legacyV1)
            .map((t) => t.tripId)
            .toList(),
      );
      if (!_currentAccount(owner, epoch, proof)) return;
      final remote = {for (final row in batch.snapshots) row.tripId: row};
      for (final row in page.items.where(
        (t) => t.kind == OwnedTripKind.legacyV1,
      )) {
        if (!remote.containsKey(row.tripId)) summaries.remove(row.tripId);
      }
      final legacyCache = await store.listSnapshots(handle: handle);
      if (!_currentAccount(owner, epoch, proof)) return;
      final editableCache = await store.listEditableSnapshots(handle: handle);
      if (!_currentAccount(owner, epoch, proof)) return;
      for (final row in page.items.where(
        (t) => t.kind == OwnedTripKind.editableV2,
      )) {
        if (legacyCache.any((cached) => cached.tripId == row.tripId)) {
          throw const SnapshotRejectedException('Cached trip kind changed.');
        }
        final view = await repository.readTrip(row.tripId, allowCached: false);
        if (!_currentAccount(owner, epoch, proof)) return;
        if (view.head == null) {
          summaries.remove(row.tripId);
          continue;
        }
        if (view.state != EditableTripViewState.online ||
            view.head!.ownerId != owner ||
            row.version == null ||
            view.head!.version < row.version!) {
          throw const SnapshotRejectedException(
            'Editable list head unavailable.',
          );
        }
        summaries[row.tripId] = _editableSummary(
          view.head!,
          createdAt: row.createdAt,
        );
      }
      final removed = <String>[];
      for (final cached in legacyCache.where(
        (c) => !remote.containsKey(c.tripId),
      )) {
        final checked = await adapter.readOwnedSnapshot(
          proof: proof,
          tripId: cached.tripId,
        );
        if (!_currentAccount(owner, epoch, proof)) return;
        if (checked.status == SnapshotLookupStatus.ready &&
            checked.snapshot != null) {
          remote[cached.tripId] = checked.snapshot!;
        } else if ({
          SnapshotLookupStatus.deleted,
          SnapshotLookupStatus.unavailable,
        }.contains(checked.status)) {
          removed.add(cached.tripId);
          summaries.remove(cached.tripId);
        } else {
          throw const SnapshotRejectedException(
            'Absent legacy recheck failed.',
          );
        }
      }
      for (final cached in editableCache.where(
        (c) => !page.items.any((t) => t.tripId == c.head.tripId),
      )) {
        final view = await repository.readTrip(
          cached.head.tripId,
          allowCached: false,
        );
        if (!_currentAccount(owner, epoch, proof)) return;
        if (view.head == null) {
          summaries.remove(cached.head.tripId);
          continue;
        }
        if (view.state != EditableTripViewState.online ||
            view.head!.ownerId != owner) {
          throw const SnapshotRejectedException(
            'Absent editable recheck failed.',
          );
        }
        summaries[cached.head.tripId] = _editableSummary(
          view.head!,
          createdAt:
              summaries[cached.head.tripId]?.createdAt ??
              _visibleTrips
                  .where((t) => t.tripId == cached.head.tripId)
                  .firstOrNull
                  ?.createdAt,
        );
      }
      for (final row in remote.values) {
        if (row.ownerId != owner) {
          throw const SnapshotRejectedException('Legacy owner mismatch.');
        }
        if (!_currentAccount(owner, epoch, proof)) return;
        await store.replaceSnapshot(
          handle: handle,
          tripId: row.tripId,
          payload: row.payload,
          remoteVersion: row.remoteVersion,
          fetchedAt: row.fetchedAt,
        );
        summaries.putIfAbsent(
          row.tripId,
          () => _legacySummary(_fromRemote(row)),
        );
      }
      for (final id in removed) {
        if (!_currentAccount(owner, epoch, proof)) return;
        await store.deleteSnapshot(handle: handle, tripId: id);
      }
      final cache = await store.listSnapshots(handle: handle);
      if (!_currentAccount(owner, epoch, proof)) return;
      _accountSnapshots = cache;
      _trips = remote.values.map(_fromRemote).toList();
      _visibleTrips = summaries.values.toList();
      _sortVisible();
      _nextCursor = page.nextCursor;
      _cacheState = AccountCacheState.online;
      _cacheErrorMessage = null;
      _cacheWriteMessage = null;
    } on EditableRemoteException catch (error) {
      if (!_currentAccount(owner, epoch, proof)) return;
      if (error.code == 'unauthorized') {
        lifecycle.invalidateAccountContext();
        clearLocal();
        _cacheState = AccountCacheState.blocked;
        _cacheErrorMessage = 'Phiên đăng nhập cần được kiểm tra lại.';
        _notifyDeferred();
      } else if (error.kind == EditableRemoteFailure.uncertain) {
        await _tryMixedOffline(store, handle, owner, epoch, proof);
      } else {
        _visibleTrips = [];
        _trips = [];
        _accountSnapshots = [];
        _nextCursor = null;
        _cacheState = AccountCacheState.error;
        _cacheErrorMessage =
            error.kind == EditableRemoteFailure.deploymentBlocked
            ? 'Chức năng danh sách chuyến đi chưa sẵn sàng trên máy chủ.'
            : 'Không thể kiểm tra danh sách chuyến đi an toàn.';
      }
    } on DioException catch (error) {
      if (!_currentAccount(owner, epoch, proof)) return;
      if ({401, 403}.contains(error.response?.statusCode)) {
        lifecycle.invalidateAccountContext();
        clearLocal();
        _cacheState = AccountCacheState.blocked;
        _cacheErrorMessage = 'Phiên đăng nhập cần được kiểm tra lại.';
      } else if (_isConnectivityError(error)) {
        await _tryMixedOffline(store, handle, owner, epoch, proof);
      } else {
        _cacheState = AccountCacheState.error;
        _cacheErrorMessage = 'Không thể kiểm tra danh sách chuyến đi.';
      }
    } catch (_) {
      if (_currentAccount(owner, epoch, proof)) {
        _cacheState = AccountCacheState.error;
        _cacheErrorMessage = 'Dữ liệu chuyến đi chưa thể kiểm tra an toàn.';
      }
    } finally {
      finish();
      if (_currentAccount(owner, epoch, proof)) {
        _isLoading = false;
        _notifyDeferred();
      }
    }
  }

  Future<void> _loadOwnedTrips(String? userId) async {
    if (_editableRepository != null) {
      await _loadMixedTrips(userId);
      return;
    }
    final lifecycle = _lifecycle;
    final store = _cacheStore;
    final adapter = _snapshotService;
    final handle = _accountHandle;
    if (handle != null && userId != handle.ownerId) return;
    if (userId == null ||
        lifecycle == null ||
        store == null ||
        adapter == null ||
        handle == null) {
      clearLocal();
      return;
    }
    AccountSessionProof proof;
    try {
      proof = lifecycle.captureProof();
    } catch (_) {
      clearLocal();
      return;
    }
    final epoch = ++_sessionEpoch;
    VoidCallback finish;
    try {
      finish = lifecycle.beginAccountOperation(proof);
    } catch (_) {
      if (_accountHandle == handle) clearLocal();
      return;
    }
    _isLoading = true;
    _cacheState = AccountCacheState.loading;
    _cacheErrorMessage = null;
    _errorMessage = null;
    _notifyDeferred();
    try {
      final batch = await adapter.fetchSnapshots(proof: proof);
      if (!_currentAccount(userId, epoch, proof)) return;
      final existing = await store.listSnapshots(handle: handle);
      if (!_currentAccount(userId, epoch, proof)) return;
      final remote = <String, RemoteTripSnapshot>{
        for (final snapshot in batch.snapshots) snapshot.tripId: snapshot,
      };
      if (remote.length != batch.snapshots.length) {
        throw const SnapshotRejectedException('Duplicate trip in list.');
      }
      final removed = <String>[];
      for (final cached in existing) {
        if (remote.containsKey(cached.tripId)) continue;
        final checked = await adapter.readOwnedSnapshot(
          proof: proof,
          tripId: cached.tripId,
        );
        if (!_currentAccount(userId, epoch, proof)) return;
        if (checked.status == SnapshotLookupStatus.ready &&
            checked.snapshot != null) {
          remote[cached.tripId] = checked.snapshot!;
        } else if (checked.status == SnapshotLookupStatus.deleted ||
            checked.status == SnapshotLookupStatus.unavailable) {
          removed.add(cached.tripId);
        } else {
          throw const SnapshotRejectedException('Absent trip recheck failed.');
        }
      }
      for (final snapshot in remote.values) {
        if (snapshot.ownerId != userId) {
          throw const SnapshotRejectedException('Trip owner mismatch.');
        }
        if (!_currentAccount(userId, epoch, proof)) return;
        await store.replaceSnapshot(
          handle: handle,
          tripId: snapshot.tripId,
          payload: snapshot.payload,
          remoteVersion: snapshot.remoteVersion,
          fetchedAt: snapshot.fetchedAt,
        );
      }
      for (final tripId in removed) {
        if (!_currentAccount(userId, epoch, proof)) return;
        await store.deleteSnapshot(handle: handle, tripId: tripId);
      }
      final cache = await store.listSnapshots(handle: handle);
      if (!_currentAccount(userId, epoch, proof)) return;
      _accountSnapshots = cache;
      _trips = remote.values.map(_fromRemote).toList();
      _cacheState = AccountCacheState.online;
      _cacheErrorMessage = null;
      _cacheWriteMessage = null;
      _errorMessage = null;
    } on DioException catch (error) {
      if (!_currentAccount(userId, epoch, proof)) return;
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        lifecycle.invalidateAccountContext();
        clearLocal();
        _cacheState = AccountCacheState.blocked;
        _cacheErrorMessage = 'Phiên đăng nhập cần được kiểm tra lại.';
        _notifyDeferred();
      } else if (_isConnectivityError(error)) {
        try {
          await _showOwnedOffline(store, handle, userId, epoch, proof);
        } catch (_) {
          if (_currentAccount(userId, epoch, proof)) {
            _cacheState = AccountCacheState.error;
            _cacheErrorMessage = 'Cache trên máy chưa thể đọc an toàn.';
          }
        }
      } else {
        _cacheState = AccountCacheState.error;
        _cacheErrorMessage = 'Không thể xác thực danh sách chuyến đi.';
      }
    } on SocketException catch (_) {
      if (_currentAccount(userId, epoch, proof)) {
        try {
          await _showOwnedOffline(store, handle, userId, epoch, proof);
        } catch (_) {
          if (_currentAccount(userId, epoch, proof)) {
            _cacheState = AccountCacheState.error;
            _cacheErrorMessage = 'Cache trên máy chưa thể đọc an toàn.';
          }
        }
      }
    } on TimeoutException catch (_) {
      if (_currentAccount(userId, epoch, proof)) {
        try {
          await _showOwnedOffline(store, handle, userId, epoch, proof);
        } catch (_) {
          if (_currentAccount(userId, epoch, proof)) {
            _cacheState = AccountCacheState.error;
            _cacheErrorMessage = 'Cache trên máy chưa thể đọc an toàn.';
          }
        }
      }
    } catch (_) {
      if (_currentAccount(userId, epoch, proof)) {
        _cacheState = AccountCacheState.error;
        _cacheErrorMessage = 'Dữ liệu chuyến đi chưa thể kiểm tra an toàn.';
      }
    } finally {
      finish();
      if (_currentAccount(userId, epoch, proof)) {
        _isLoading = false;
        _notifyDeferred();
      }
    }
  }

  Future<void> _showOwnedOffline(
    LocalTripStore store,
    SessionHandle handle,
    String owner,
    int epoch,
    AccountSessionProof proof,
  ) async {
    final cache = await store.listSnapshots(handle: handle);
    if (!_currentAccount(owner, epoch, proof)) return;
    _accountSnapshots = cache;
    _trips = cache.map(_fromCached).toList();
    if (_editableRepository != null) {
      final editable = await store.listEditableSnapshots(handle: handle);
      if (!_currentAccount(owner, epoch, proof)) return;
      _visibleTrips = [
        ..._trips.map(_legacySummary),
        ...editable.map((row) => _editableSummary(row.head)),
      ];
      _sortVisible();
      _nextCursor = null;
    }
    final empty = _editableRepository == null
        ? cache.isEmpty
        : _visibleTrips.isEmpty;
    _cacheState = empty
        ? AccountCacheState.unavailable
        : AccountCacheState.offline;
    _cacheErrorMessage = empty ? 'Chưa có chuyến đi lưu trên máy.' : null;
    _errorMessage = null;
  }

  static bool _isConnectivityError(DioException error) =>
      error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout;

  static SavedTrip _fromRemote(RemoteTripSnapshot snapshot) {
    final metadata = snapshot.payload.metadata;
    final request = snapshot.payload.request;
    final headers = snapshot.headers;
    final startStr = headers.startDate ?? metadata.startDate ?? request?.startDate;
    final endStr = headers.endDate ?? metadata.endDate ?? request?.endDate;
    final numDays = headers.numDays is int
        ? headers.numDays as int
        : (request?.numDays ??
            (startStr != null && endStr != null
                ? (DateTime.parse(endStr).difference(DateTime.parse(startStr)).inDays + 1)
                : null));
    return SavedTrip(
      id: snapshot.tripId,
      userId: snapshot.ownerId,
      title: headers.title ?? metadata.title ?? 'Chuyến đi',
      destinationName:
          headers.destinationName ?? metadata.destinationName ?? 'Điểm đến',
      numDays: numDays,
      budgetTotal:
          headers.budgetTotal?.toDouble() ?? request?.budgetVnd.toDouble(),
      startDate: startStr == null ? null : DateTime.tryParse(startStr),
      endDate: endStr == null ? null : DateTime.tryParse(endStr),
      status: headers.status ?? 'planning',
      tripPlanData: TripPayloadCodec.encodeToMap(snapshot.payload),
      createdAt: headers.createdAt == null
          ? null
          : DateTime.tryParse(headers.createdAt!),
    );
  }

  static SavedTrip _fromCached(AccountTripSnapshotRecord snapshot) {
    final payload = snapshot.cachedPayload;
    final metadata = payload.metadata;
    final request = payload.request;
    final startStr = metadata.startDate ?? request?.startDate;
    final endStr = metadata.endDate ?? request?.endDate;
    final numDays = request?.numDays ??
        (startStr != null && endStr != null
            ? (DateTime.parse(endStr).difference(DateTime.parse(startStr)).inDays + 1)
            : null);
    return SavedTrip(
      id: snapshot.tripId,
      userId: snapshot.ownerId,
      title: snapshot.title,
      destinationName: snapshot.destinationName,
      numDays: numDays,
      budgetTotal: request?.budgetVnd.toDouble(),
      startDate: startStr == null ? null : DateTime.tryParse(startStr),
      endDate: endStr == null ? null : DateTime.tryParse(endStr),
      tripPlanData: TripPayloadCodec.encodeToMap(payload),
      createdAt: null,
    );
  }

  Future<bool> saveTrip({
    required String title,
    required String destinationName,
    required int numDays,
    required double budgetTotal,
    DateTime? startDate,
    DateTime? endDate,
    required Map<String, dynamic> tripPlanData,
  }) async {
    if (_isDisposed) return false;
    AccountSessionProof? proof;
    VoidCallback? finish;
    if (requiresLifecycle) {
      try {
        final lifecycle = _lifecycle;
        if (lifecycle == null || _accountHandle == null) return false;
        proof = lifecycle.captureProof();
        if (proof.ownerId != _accountHandle!.ownerId) return false;
        finish = lifecycle.beginAccountOperation(proof);
      } catch (_) {
        _errorMessage = 'Phiên đăng nhập chưa sẵn sàng để lưu.';
        _notifyDeferred();
        return false;
      }
    }
    try {
      return await _saveTripAuthorized(
        title: title,
        destinationName: destinationName,
        numDays: numDays,
        budgetTotal: budgetTotal,
        startDate: startDate,
        endDate: endDate,
        tripPlanData: tripPlanData,
        proof: proof,
      );
    } finally {
      finish?.call();
    }
  }

  Future<bool> _saveTripAuthorized({
    required String title,
    required String destinationName,
    required int numDays,
    required double budgetTotal,
    required Map<String, dynamic> tripPlanData,
    required AccountSessionProof? proof,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_currentUserId == null || _currentUserId!.isEmpty) {
      _errorMessage = 'Vui lòng đăng nhập để lưu chuyến đi.';
      if (!_isDisposed) notifyListeners();
      return false;
    }

    final targetEpoch = _sessionEpoch;
    final targetUserId = _currentUserId!;
    _isLoading = true;
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();

    final newTrip = SavedTrip(
      id: '',
      userId: targetUserId,
      title: title,
      destinationName: destinationName,
      numDays: numDays,
      budgetTotal: budgetTotal,
      startDate: startDate,
      endDate: endDate,
      tripPlanData: tripPlanData,
      createdAt: DateTime.now(),
    );

    try {
      final saved = await _service.saveTrip(newTrip);

      // Verify not disposed and epoch/session match
      if (_isDisposed ||
          _sessionEpoch != targetEpoch ||
          _currentUserId != targetUserId ||
          (proof != null &&
              !_currentAccount(targetUserId, targetEpoch, proof))) {
        return false;
      }

      // STRICT LAW: Success only after valid server ID acknowledgement
      if (saved.id.isNotEmpty && saved.userId == targetUserId) {
        _trips.insert(0, saved);
        if (_editableRepository != null) {
          _visibleTrips.removeWhere((t) => t.tripId == saved.id);
          _visibleTrips.insert(0, _legacySummary(saved));
          _sortVisible();
        }
        if (proof != null) {
          try {
            final lookedUp = await _snapshotService!.readOwnedSnapshot(
              proof: proof,
              tripId: saved.id,
            );
            if (!_currentAccount(targetUserId, targetEpoch, proof)) {
              return false;
            }
            if (lookedUp.status != SnapshotLookupStatus.ready ||
                lookedUp.snapshot == null) {
              throw const SnapshotRejectedException(
                'Saved trip is not readable.',
              );
            }
            final remote = lookedUp.snapshot!;
            await _cacheStore!.replaceSnapshot(
              handle: _accountHandle!,
              tripId: saved.id,
              payload: remote.payload,
              remoteVersion: remote.remoteVersion,
              fetchedAt: remote.fetchedAt,
            );
            if (!_currentAccount(targetUserId, targetEpoch, proof)) {
              return false;
            }
            _accountSnapshots = await _cacheStore!.listSnapshots(
              handle: _accountHandle!,
            );
            _cacheWriteMessage = null;
          } catch (_) {
            if (!_currentAccount(targetUserId, targetEpoch, proof)) {
              return false;
            }
            _cacheWriteMessage =
                'Đã lưu trên máy chủ; chưa thể cập nhật bản trên máy.';
          }
        }
        _errorMessage = null;
        _isLoading = false;
        if (!_isDisposed) notifyListeners();
        return true;
      } else {
        _errorMessage = 'Máy chủ trả về phản hồi không hợp lệ.';
        _isLoading = false;
        if (!_isDisposed) notifyListeners();
        return false;
      }
    } catch (e) {
      if (_isDisposed ||
          _sessionEpoch != targetEpoch ||
          _currentUserId != targetUserId ||
          (proof != null &&
              !_currentAccount(targetUserId, targetEpoch, proof))) {
        return false;
      }
      _errorMessage = 'Không thể lưu chuyến đi lên máy chủ: ${e.toString()}';
      _isLoading = false;
      if (!_isDisposed) notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTrip(String tripId) async {
    if (_isDisposed) return false;
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    AccountSessionProof? proof;
    VoidCallback? finish;
    if (requiresLifecycle) {
      try {
        final lifecycle = _lifecycle;
        if (lifecycle == null || _accountHandle == null) return false;
        proof = lifecycle.captureProof();
        if (proof.ownerId != _accountHandle!.ownerId) return false;
        finish = lifecycle.beginAccountOperation(proof);
      } catch (_) {
        _errorMessage = 'Phiên đăng nhập chưa sẵn sàng để xóa.';
        _notifyDeferred();
        return false;
      }
    }
    try {
      return await _deleteTripAuthorized(tripId, proof);
    } finally {
      finish?.call();
    }
  }

  Future<bool> _deleteTripAuthorized(
    String tripId,
    AccountSessionProof? proof,
  ) async {
    final targetEpoch = _sessionEpoch;
    final targetUserId = _currentUserId!;

    final index = _trips.indexWhere((t) => t.id == tripId);
    if (index < 0) return false;

    final removed = _trips.removeAt(index);
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();

    try {
      final success = await _service.deleteTrip(
        tripId: tripId,
        userId: targetUserId,
      );

      // Drop late acknowledgements if disposed, epoch changed, or user changed
      if (_isDisposed ||
          _sessionEpoch != targetEpoch ||
          _currentUserId != targetUserId ||
          (proof != null &&
              !_currentAccount(targetUserId, targetEpoch, proof))) {
        return false;
      }

      if (!success) {
        _trips.insert(index, removed);
        _errorMessage = 'Không thể xóa chuyến đi khỏi máy chủ.';
        notifyListeners();
        return false;
      }
      _visibleTrips.removeWhere((t) => t.tripId == tripId);
      if (proof != null) {
        try {
          await _cacheStore!.deleteSnapshot(
            handle: _accountHandle!,
            tripId: tripId,
          );
          if (!_currentAccount(targetUserId, targetEpoch, proof)) return false;
          _accountSnapshots = await _cacheStore!.listSnapshots(
            handle: _accountHandle!,
          );
          _cacheWriteMessage = null;
        } catch (_) {
          if (!_currentAccount(targetUserId, targetEpoch, proof)) return false;
          _cacheWriteMessage =
              'Đã xóa trên máy chủ; bản trên máy chưa được cập nhật.';
        }
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (!_isDisposed &&
          _sessionEpoch == targetEpoch &&
          _currentUserId == targetUserId &&
          (proof == null ||
              _currentAccount(targetUserId, targetEpoch, proof))) {
        _trips.insert(index, removed);
        _errorMessage = 'Lỗi khi xóa chuyến đi: ${e.toString()}';
        notifyListeners();
      }
      return false;
    }
  }

  void clearLocal() {
    _visibleTrips = [];
    _nextCursor = null;
    _sessionEpoch++;
    _trips = [];
    _currentUserId = null;
    _errorMessage = null;
    _isLoading = false;
    _pendingFetchUserId = null;
    _pendingFetchEpoch = null;
    _accountSnapshots = [];
    _cacheState = AccountCacheState.idle;
    _cacheErrorMessage = null;
    _cacheWriteMessage = null;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sessionEpoch++;
    _pendingFetchUserId = null;
    _pendingFetchEpoch = null;
    super.dispose();
  }

  /// Synchronously align user context during ProxyProvider.update to avoid
  /// cross-account cache exposure in intermediate build frames.
  void updateAuthContext({
    required bool isAuthenticated,
    required bool isDemoSession,
    required String? userId,
  }) {
    if (_isDisposed) return;
    if (requiresLifecycle) {
      final authorized =
          isAuthenticated &&
          !isDemoSession &&
          userId != null &&
          userId == _accountHandle?.ownerId &&
          _lifecycle?.handle == _accountHandle;
      if (!authorized &&
          (_currentUserId != null ||
              _trips.isNotEmpty ||
              _accountSnapshots.isNotEmpty)) {
        unbindAccount();
      }
      return;
    }
    if (isAuthenticated &&
        !isDemoSession &&
        userId != null &&
        userId.isNotEmpty) {
      if (_currentUserId != userId) {
        _sessionEpoch++;
        _trips = [];
        _currentUserId = userId;
        _errorMessage = null;
        _isLoading = true;
        _pendingFetchUserId = userId;
        _pendingFetchEpoch = _sessionEpoch;
      }
    } else {
      if (_currentUserId != null ||
          _trips.isNotEmpty ||
          _pendingFetchUserId != null) {
        _sessionEpoch++;
        _trips = [];
        _currentUserId = null;
        _errorMessage = null;
        _isLoading = false;
        _pendingFetchUserId = null;
        _pendingFetchEpoch = null;
      }
    }
  }

  /// Trigger pending fetch deferred to post-frame safely.
  void fetchIfPending() {
    if (_isDisposed) return;
    if (requiresLifecycle && _accountHandle == null) return;
    final targetUserId = _pendingFetchUserId;
    final targetEpoch = _pendingFetchEpoch;
    _pendingFetchUserId = null;
    _pendingFetchEpoch = null;
    if (targetUserId != null &&
        targetUserId.isNotEmpty &&
        targetEpoch == _sessionEpoch &&
        _currentUserId == targetUserId) {
      loadTrips(targetUserId);
    }
  }

  /// Lifecycle synchronization hook driven by AuthProvider.
  /// Ensures account isolation, demo session containment, and prevents cross-user stale cache.
  void syncWithAuth({
    required bool isAuthenticated,
    required bool isDemoSession,
    required String? userId,
  }) {
    if (_isDisposed) return;
    if (requiresLifecycle) {
      updateAuthContext(
        isAuthenticated: isAuthenticated,
        isDemoSession: isDemoSession,
        userId: userId,
      );
      return;
    }
    if (isAuthenticated &&
        !isDemoSession &&
        userId != null &&
        userId.isNotEmpty) {
      if (_currentUserId != userId) {
        loadTrips(userId);
      }
    } else {
      if (_currentUserId != null || _trips.isNotEmpty) {
        clearLocal();
      }
    }
  }
}
