import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place_review.dart';

abstract interface class PlaceReviewsRepository {
  Future<List<PlaceReview>> fetchForPlace(String placeId);
  Future<PlaceReview> create({
    required String placeId,
    required int rating,
    required String content,
  });
}

class PlaceReviewFailure implements Exception {
  final String code;
  const PlaceReviewFailure(this.code);
  @override
  String toString() => 'PlaceReviewFailure($code)';
}

class SupabasePlaceReviewsService implements PlaceReviewsRepository {
  final SupabaseClient client;
  const SupabasePlaceReviewsService(this.client);

  @override
  Future<List<PlaceReview>> fetchForPlace(String placeId) async {
    try {
      final rows = await client
          .from('place_reviews')
          .select()
          .eq('place_id', placeId)
          .order('created_at', ascending: false);
      return rows
          .map((row) => PlaceReview.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw PlaceReviewFailure(error.code ?? 'server_error');
    } catch (_) {
      throw const PlaceReviewFailure('network_error');
    }
  }

  @override
  Future<PlaceReview> create({
    required String placeId,
    required int rating,
    required String content,
  }) async {
    if (rating < 1 || rating > 5) {
      throw const PlaceReviewFailure('invalid_rating');
    }
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed.length > 1000) {
      throw const PlaceReviewFailure('invalid_content');
    }
    if (client.auth.currentSession?.user.id == null) {
      throw const PlaceReviewFailure('authentication_required');
    }
    try {
      final row = await client
          .from('place_reviews')
          .insert({'place_id': placeId, 'rating': rating, 'content': trimmed})
          .select()
          .single();
      return PlaceReview.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const PlaceReviewFailure('already_reviewed');
      }
      if (error.code == '42501') {
        throw const PlaceReviewFailure('authentication_required');
      }
      throw PlaceReviewFailure(error.code ?? 'server_error');
    } catch (_) {
      throw const PlaceReviewFailure('network_error');
    }
  }
}
