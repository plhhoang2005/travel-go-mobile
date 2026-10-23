// Public catalogue provider for Discovery Release V2.

import 'package:flutter/foundation.dart';
import 'package:travelgo_mobile/features/explore/models/public_catalogue_snapshot.dart';
import 'package:travelgo_mobile/features/explore/services/public_catalogue_repository.dart';

class PublicCatalogueProvider extends ChangeNotifier {
  final PublicCatalogueRepository repository;

  PublicCatalogueSnapshot? _snapshot;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefreshedAt;
  int _generation = 0;
  bool _disposed = false;

  PublicCatalogueProvider({required this.repository});

  PublicCatalogueSnapshot? get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefreshedAt => _lastRefreshedAt;

  Future<void> load() async {
    _generation++;
    final currentGen = _generation;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final s = await repository.load();
      if (!_disposed && _generation == currentGen) {
        _snapshot = s;
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (!_disposed && _generation == currentGen) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh({bool force = false}) async {
    _generation++;
    final currentGen = _generation;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await repository.refresh(force: force);
      if (!_disposed && _generation == currentGen) {
        _snapshot = result.snapshot;
        if (result.updated) {
          _lastRefreshedAt = DateTime.now();
        }
        if (result.errorCode != null) {
          _error = result.errorCode;
        }
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (!_disposed && _generation == currentGen) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> onResume() => refresh(force: false);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
