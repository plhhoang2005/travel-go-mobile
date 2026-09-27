import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_trip_model.dart';

class TripsService {
  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<SavedTrip>> fetchTrips(String userId) async {
    final client = _client;
    if (client == null) return [];

    try {
      final response = await client
          .from('saved_trips')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = (response as List<dynamic>)
          .map((item) => SavedTrip.fromJson(item as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      debugPrint('Error fetching trips from Supabase: $e');
      return [];
    }
  }

  Future<SavedTrip?> saveTrip(SavedTrip trip) async {
    final client = _client;
    if (client == null) return null;

    try {
      final response = await client
          .from('saved_trips')
          .insert(trip.toJson())
          .select()
          .single();

      return SavedTrip.fromJson(response);
    } catch (e) {
      debugPrint('Error saving trip to Supabase: $e');
      return null;
    }
  }

  Future<bool> deleteTrip({
    required String tripId,
    required String userId,
  }) async {
    final client = _client;
    if (client == null) return false;

    try {
      await client
          .from('saved_trips')
          .delete()
          .eq('id', tripId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      debugPrint('Error deleting trip from Supabase: $e');
      return false;
    }
  }
}
