import 'package:flutter/foundation.dart';

import '../models/catalogue_reference.dart';
import '../services/catalogue_repository.dart';

enum DiscoveryLoadState { loading, ready, error }

class DiscoveryProvider extends ChangeNotifier {
  final CatalogueRepository _repository;
  DiscoveryProvider({CatalogueRepository? repository})
    : _repository = repository ?? CatalogueRepository();
  CatalogueReference? _catalogue;
  DiscoveryLoadState _state = DiscoveryLoadState.loading;
  String _query = '';
  String? _region;
  int _loadGeneration = 0;
  bool _disposed = false, _started = false;
  CatalogueReference? get catalogue => _catalogue;
  DiscoveryLoadState get state => _state;
  String get query => _query;
  String? get region => _region;
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
    _state = DiscoveryLoadState.loading;
    _catalogue = null;
    notifyListeners();
    try {
      final result = await _repository.load();
      if (_disposed || generation != _loadGeneration) return;
      _catalogue = result;
      _state = DiscoveryLoadState.ready;
    } catch (_) {
      if (_disposed || generation != _loadGeneration) return;
      _state = DiscoveryLoadState.error;
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
