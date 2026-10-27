// Central coordinator providing atomic catalogue synchronization and single-flight refresh
// between mobile client presentation layers and remote release publications.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/explore/models/unified_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_repository.dart';

enum UnifiedSyncStatus {
  idle,
  syncing,
  upToDate,
  updated,
  error,
}

@immutable
class UnifiedSyncResult {
  final UnifiedCatalogueSnapshot snapshot;
  final bool updated;
  final String? errorCode;
  final UnifiedSyncStatus status;

  const UnifiedSyncResult({
    required this.snapshot,
    required this.updated,
    this.errorCode,
    required this.status,
  });
}

class CatalogueSyncCoordinator extends ChangeNotifier {
  final PublicCatalogueRepository repository;
  final DateTime Function() clock;
  final Duration minRefreshInterval;

  UnifiedCatalogueSnapshot? _snapshot;
  Future<UnifiedSyncResult>? _inFlightSync;
  Future<UnifiedCatalogueSnapshot>? _inFlightLoad;
  DateTime? _lastSyncAttemptAt;
  DateTime? _lastSuccessfulSyncAt;
  String? _lastErrorCode;
  bool _isSyncing = false;
  bool _disposed = false;

  CatalogueSyncCoordinator({
    required this.repository,
    DateTime Function()? clock,
    this.minRefreshInterval = const Duration(minutes: 15),
  }) : clock = clock ?? (() => DateTime.now().toUtc());

  UnifiedCatalogueSnapshot? get snapshot => _snapshot;
  bool get isSyncing => _isSyncing;
  bool get hasSnapshot => _snapshot != null;
  String? get lastErrorCode => _lastErrorCode;
  DateTime? get lastSyncAttemptAt => _lastSyncAttemptAt;
  DateTime? get lastSuccessfulSyncAt => _lastSuccessfulSyncAt;

  /// Nạp snapshot cục bộ từ Seed hoặc SQLite Cache (không gọi mạng).
  Future<UnifiedCatalogueSnapshot> loadLocal() async {
    if (_disposed) {
      throw StateError('CatalogueSyncCoordinator is disposed');
    }
    if (_snapshot != null) {
      return _snapshot!;
    }
    final pending = _inFlightLoad;
    if (pending != null) {
      return pending;
    }

    final completer = Completer<UnifiedCatalogueSnapshot>();
    _inFlightLoad = completer.future;

    try {
      final publicSnapshot = await repository.load();
      final unified = UnifiedCatalogueSnapshot.fromPublicSnapshot(publicSnapshot);
      if (!_disposed) {
        _snapshot = unified;
        _notifySafely();
      }
      completer.complete(unified);
      return unified;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _inFlightLoad = null;
    }
  }

  /// Đồng bộ danh mục với remote storage có cơ chế Single-Flight và bảo tồn Last-Known-Good.
  Future<UnifiedSyncResult> sync({bool force = false}) async {
    if (_disposed) {
      throw StateError('CatalogueSyncCoordinator is disposed');
    }

    // 1. Tái sử dụng request đang chạy (Single-Flight deduplication)
    final pending = _inFlightSync;
    if (pending != null) {
      return pending;
    }

    // 2. Kiểm tra tần suất làm mới nếu không ép buộc (force = false)
    final now = clock();
    final lastAttempt = _lastSyncAttemptAt;
    if (!force &&
        lastAttempt != null &&
        now.difference(lastAttempt) < minRefreshInterval &&
        _snapshot != null) {
      return UnifiedSyncResult(
        snapshot: _snapshot!,
        updated: false,
        status: UnifiedSyncStatus.upToDate,
      );
    }

    final completer = Completer<UnifiedSyncResult>();
    _inFlightSync = completer.future;
    _lastSyncAttemptAt = now;
    _isSyncing = true;
    _notifySafely();

    unawaited(() async {
      try {
        // Đảm bảo đã có snapshot cục bộ trước khi refresh
        if (_snapshot == null) {
          await loadLocal();
        }

        final refreshResult = await repository.refresh(force: force);
        final newUnified = UnifiedCatalogueSnapshot.fromPublicSnapshot(refreshResult.snapshot);

        if (_disposed) {
          completer.complete(UnifiedSyncResult(
            snapshot: newUnified,
            updated: refreshResult.updated,
            status: refreshResult.updated ? UnifiedSyncStatus.updated : UnifiedSyncStatus.upToDate,
          ));
          return;
        }

        final wasUpdated = refreshResult.updated;
        _snapshot = newUnified;
        if (wasUpdated) {
          _lastSuccessfulSyncAt = clock();
        }
        _lastErrorCode = refreshResult.errorCode;
        _isSyncing = false;

        final result = UnifiedSyncResult(
          snapshot: newUnified,
          updated: wasUpdated,
          errorCode: refreshResult.errorCode,
          status: wasUpdated
              ? UnifiedSyncStatus.updated
              : (refreshResult.errorCode != null
                  ? UnifiedSyncStatus.error
                  : UnifiedSyncStatus.upToDate),
        );

        _notifySafely();
        completer.complete(result);
      } catch (e) {
        if (_disposed) {
          completer.completeError(e);
          return;
        }

        _isSyncing = false;
        _lastErrorCode = e.toString();
        _notifySafely();

        // Bảo tồn Last-Known-Good snapshot nếu đã có
        if (_snapshot != null) {
          completer.complete(UnifiedSyncResult(
            snapshot: _snapshot!,
            updated: false,
            errorCode: e.toString(),
            status: UnifiedSyncStatus.error,
          ));
        } else {
          completer.completeError(e);
        }
      } finally {
        _inFlightSync = null;
      }
    }());

    return completer.future;
  }

  /// Khởi tạo toàn diện: nạp local trước rồi thăm dò bản mới trong nền.
  Future<void> initialize() async {
    await loadLocal();
    unawaited(sync(force: true));
  }

  /// Kích hoạt khi app từ nền quay lại foreground.
  Future<void> onResume() => sync(force: true);

  void _notifySafely() {
    if (_disposed) return;
    scheduleMicrotask(() {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

