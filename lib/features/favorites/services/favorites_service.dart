import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/favorite_item_model.dart';

class FavoritesService {
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<FavoriteItem>> fetchFavorites(String userId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((item) => FavoriteItem.fromJson(item as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      debugPrint('Error fetching favorites from Supabase: $e');
      return [];
    }
  }

  Future<bool> addFavorite(FavoriteItem item) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client.from('favorites').upsert(
            item.toJson(),
            onConflict: 'user_id,item_id,item_type',
          );
      return true;
    } catch (e) {
      debugPrint('Error adding favorite to Supabase: $e');
      return false;
    }
  }

  Future<bool> removeFavorite({
    required String userId,
    required String itemId,
    required String itemType,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('item_id', itemId)
          .eq('item_type', itemType);
      return true;
    } catch (e) {
      debugPrint('Error removing favorite from Supabase: $e');
      return false;
    }
  }
}
