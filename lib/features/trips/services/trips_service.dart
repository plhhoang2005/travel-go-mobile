import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_trip_model.dart';

class TripsService {
  static const String tableName = 'trips';
  final SupabaseClient? _injectedClient;

  TripsService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _validateSessionOwner(String userId, SupabaseClient client) {
    final session = client.auth.currentSession;
    final currentUser = client.auth.currentUser;
    if (session == null || currentUser == null || currentUser.id != userId || session.isExpired) {
      throw StateError('Không có phiên làm việc Supabase hợp lệ hoặc phiên người dùng không khớp.');
    }
  }

  Future<List<SavedTrip>> fetchTrips(String userId) async {
    final client = _client;
    if (client == null) {
      throw StateError('Chưa thể kết nối tới cơ sở dữ liệu Supabase.');
    }

    _validateSessionOwner(userId, client);

    final response = await client
        .from(tableName)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final list = (response as List<dynamic>)
        .map((item) => SavedTrip.fromJson(item as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<SavedTrip> saveTrip(SavedTrip trip) async {
    final client = _client;
    if (client == null) {
      throw StateError('Chưa thể kết nối tới cơ sở dữ liệu Supabase.');
    }

    _validateSessionOwner(trip.userId, client);

    if (trip.title.trim().isEmpty) {
      throw ArgumentError('Tiêu đề chuyến đi không được để trống.');
    }
    if (trip.destinationName.trim().isEmpty) {
      throw ArgumentError('Điểm đến không được để trống.');
    }

    final payload = trip.toJson(includeId: trip.id.isNotEmpty);
    final response = await client
        .from(tableName)
        .insert(payload)
        .select()
        .single();

    final saved = SavedTrip.fromJson(response);
    if (saved.id.isEmpty) {
      throw StateError('Máy chủ không trả về mã định danh ID hợp lệ.');
    }
    return saved;
  }

  Future<bool> deleteTrip({
    required String tripId,
    required String userId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Chưa thể kết nối tới cơ sở dữ liệu Supabase.');
    }

    _validateSessionOwner(userId, client);

    final response = await client
        .from(tableName)
        .delete()
        .eq('id', tripId)
        .eq('user_id', userId)
        .select('id, user_id');

    final list = response as List<dynamic>;
    return list.isNotEmpty &&
        list.any((item) =>
            item is Map &&
            item['id'] == tripId &&
            item['user_id'] == userId);
  }
}
