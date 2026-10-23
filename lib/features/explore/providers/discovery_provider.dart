import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';

import '../models/catalogue_reference.dart';
import '../services/catalogue_repository.dart';

enum DiscoveryLoadState { loading, ready, error }

class DiscoveryProvider extends ChangeNotifier {
  final CatalogueRepository _repository;
  final Future<PublicCatalogueSnapshot> Function(bool force)? publicSnapshotLoader;

  DiscoveryProvider({
    CatalogueRepository? repository,
    this.publicSnapshotLoader,
  }) : _repository = repository ?? CatalogueRepository();

  CatalogueReference? _catalogue;
  DiscoveryLoadState _state = DiscoveryLoadState.loading;
  String _query = '';
  String? _region;
  int _loadGeneration = 0;
  bool _disposed = false, _started = false;
  int? _version;
  String? _sha256;

  CatalogueReference? get catalogue => _catalogue;
  DiscoveryLoadState get state => _state;
  String get query => _query;
  String? get region => _region;
  int? get version => _version;
  String? get sha256 => _sha256;

  void bindPublicSnapshot(PublicCatalogueSnapshot snapshot) {
    if (_disposed) return;
    if (_version == snapshot.version && _sha256 == snapshot.sha256 && _catalogue != null) return;
    _version = snapshot.version;
    _sha256 = snapshot.sha256;
    _catalogue = snapshot.catalogue;
    _state = DiscoveryLoadState.ready;
    _started = true;
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
  List<DestinationReference> get visibleDestinations {
    final query = foldSearch(_query);
    return List.unmodifiable(
      (_catalogue?.destinations ?? <DestinationReference>[]).where(
        (d) =>
            (_region == null || d.region == _region) &&
            foldSearch(d.name).contains(query),
      ),
    );
  }

  void setQuery(String value) {
    if (_disposed || _query == value) return;
    _query = value;
    notifyListeners();
  }

  void setRegion(String? value) {
    if (_disposed || _region == value) return;
    _region = value;
    notifyListeners();
  }

  Future<void> load({bool force = false}) async {
    if (_disposed || (_started && !force)) return;
    _started = true;
    final generation = ++_loadGeneration;
    if (_catalogue == null) {
      _state = DiscoveryLoadState.loading;
      notifyListeners();
    }

    if (publicSnapshotLoader != null) {
      try {
        final snapshot = await publicSnapshotLoader!(force);
        if (_disposed || generation != _loadGeneration) return;
        _version = snapshot.version;
        _sha256 = snapshot.sha256;
        _catalogue = snapshot.catalogue;
        _state = DiscoveryLoadState.ready;
      } catch (_) {
        if (_disposed || generation != _loadGeneration) return;
        if (_catalogue == null) {
          _state = DiscoveryLoadState.error;
        }
      }
    } else {
      try {
        final result = await _repository.load();
        if (_disposed || generation != _loadGeneration) return;
        _catalogue = result;
        _state = DiscoveryLoadState.ready;
      } catch (_) {
        if (_disposed || generation != _loadGeneration) return;
        if (_catalogue == null) {
          _state = DiscoveryLoadState.error;
        }
      }
    }
    if (!_disposed && generation == _loadGeneration) notifyListeners();
  }

  static String foldSearch(String text) {
    var result = text.trim().toLowerCase();
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    for (final group in groups.entries) {
      result = result.replaceAll(RegExp('[${group.value}]'), group.key);
    }
    return result.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    super.dispose();
  }
}
