import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';

import '../models/catalogue_reference.dart';
import '../services/place_visit_details_repository.dart';

class PlaceVisitDetailsProvider extends ChangeNotifier {
  final Future<VisitDetailsRepository> Function(CatalogueReference catalogue)
  repositoryFactory;
  final DateTime Function() now;
  VisitDetailsRepository? _repository;
  VisitSnapshot? _snapshot;
  Future<void>? _loadFuture, _refreshFuture;
  DateTime? _lastRefreshAttempt;
  Set<String>? _boundIds;
  String? _errorCode;
  bool _isLoading = false, _isRefreshing = false, _disposed = false;
  int _generation = 0;
  bool _boundToV2 = false;

  PlaceVisitDetailsProvider({
    required this.repositoryFactory,
    required this.now,
  });

  VisitSnapshot? get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorCode => _errorCode;
  bool get isBoundToV2 => _boundToV2;
  int? get version => _snapshot?.catalogue.version;

  void bindPublicSnapshot(PublicCatalogueSnapshot snapshot) {
    if (_disposed) return;
    if (_boundToV2 && _snapshot?.catalogue.version == snapshot.version) return;

    _boundToV2 = true;
    _boundIds = Set.unmodifiable(
      snapshot.catalogue.destinations.expand((d) => d.places).map((p) => p.id),
    );
    _snapshot = VisitSnapshot(
      catalogue: snapshot.visits,
      origin: snapshot.origin,
      sha256: snapshot.sha256,
      lastFetchedAt: snapshot.fetchedAt,
    );
    _errorCode = null;
    _isLoading = false;
    _isRefreshing = false;
    _notifySafely();
  }

  void _notifySafely() {
    if (_disposed) return;
    scheduleMicrotask(() {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  Future<void> load(CatalogueReference catalogue) {
    if (_disposed || _boundToV2) {
      return Future<void>.value();
    }
    final ids = catalogue.destinations
        .expand((d) => d.places)
        .map((p) => p.id)
        .toSet();
    if (_boundIds != null && !setEquals(_boundIds, ids)) {
      _errorCode = 'catalogue_changed';
      notifyListeners();
      return Future<void>.value();
    }
    _boundIds ??= Set.unmodifiable(ids);
    final pending = _loadFuture;
    if (pending != null) {
      return pending;
    }
    if (_snapshot != null) {
      return refresh();
    }
    // Set the in-flight future before any synchronous listener notification.
    final done = Completer<void>();
    _loadFuture = done.future;
    unawaited(() async {
      await _initialize(catalogue, _generation);
      _loadFuture = null;
      done.complete();
    }());
    return done.future;
  }

  Future<void> _initialize(CatalogueReference catalogue, int generation) async {
    _isLoading = true;
    _errorCode = null;
    notifyListeners();
    try {
      final repository = _repository ?? await repositoryFactory(catalogue);
      if (_disposed || generation != _generation) {
        await repository.close();
        return;
      }
      _repository = repository;
      final local = await repository.loadLocal();
      if (_disposed || generation != _generation) {
        return;
      }
      _snapshot = local;
      _errorCode = null;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _errorCode = 'local_unavailable';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
    if (!_disposed && generation == _generation && _snapshot != null) {
      unawaited(refresh());
    }
  }

  Future<void> refresh({bool force = false}) {
    if (_disposed || _boundToV2) {
      return Future<void>.value();
    }
    final repository = _repository;
    final current = _snapshot;
    if (repository == null || current == null) {
      return Future<void>.value();
    }
    final pending = _refreshFuture;
    if (pending != null) {
      return pending;
    }
    final attempted = _lastRefreshAttempt;
    if (!force &&
        attempted != null &&
        now().difference(attempted) < const Duration(minutes: 15)) {
      return Future<void>.value();
    }
    final done = Completer<void>();
    _refreshFuture = done.future;
    unawaited(() async {
      await _refresh(repository, current, _generation);
      _refreshFuture = null;
      done.complete();
    }());
    return done.future;
  }

  Future<void> _refresh(
    VisitDetailsRepository repository,
    VisitSnapshot current,
    int generation,
  ) async {
    _lastRefreshAttempt = now();
    _isRefreshing = true;
    _errorCode = null;
    notifyListeners();
    try {
      final result = await repository.refresh(current);
      if (_disposed || generation != _generation) {
        return;
      }
      if (result.snapshot.catalogue.version >=
          (_snapshot?.catalogue.version ?? 0)) {
        _snapshot = result.snapshot;
      }
      _errorCode = result.errorCode;
    } catch (_) {
      if (!_disposed && generation == _generation) {
        _errorCode = 'remote_unavailable';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    final repository = _repository;
    if (repository != null) {
      unawaited(repository.close().catchError((Object _) {}));
    }
    super.dispose();
  }
}
