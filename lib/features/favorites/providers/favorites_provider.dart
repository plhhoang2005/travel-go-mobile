import 'package:flutter/material.dart';
import '../models/favorite_item_model.dart';
import '../services/favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final FavoritesService _service = FavoritesService();

  List<FavoriteItem> _items = [];
  bool _isLoading = false;
  String? _currentUserId;

  List<FavoriteItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  int get count => _items.length;

  bool isFavorite(String itemId) {
    return _items.any((item) => item.itemId == itemId);
  }

  Future<void> loadFavorites(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _items = [];
      _currentUserId = null;
      notifyListeners();
      return;
    }

    _currentUserId = userId;
    _isLoading = true;
    notifyListeners();

    _items = await _service.fetchFavorites(userId);
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> toggleFavorite(FavoriteItem item) async {
    final existingIndex = _items.indexWhere((it) => it.itemId == item.itemId);

    if (existingIndex >= 0) {
      // Remove favorite
      final removedItem = _items.removeAt(existingIndex);
      notifyListeners();

      if (_currentUserId != null) {
        final success = await _service.removeFavorite(
          userId: _currentUserId!,
          itemId: item.itemId,
          itemType: item.itemType,
        );
        if (!success) {
          // Rollback on network failure
          _items.insert(existingIndex, removedItem);
          notifyListeners();
          return false;
        }
      }
      return true;
    } else {
      // Add favorite
      _items.insert(0, item);
      notifyListeners();

      if (_currentUserId != null) {
        final success = await _service.addFavorite(item);
        if (!success) {
          _items.removeWhere((it) => it.itemId == item.itemId);
          notifyListeners();
          return false;
        }
      }
      return true;
    }
  }

  void clearLocal() {
    _items = [];
    _currentUserId = null;
    notifyListeners();
  }
}
