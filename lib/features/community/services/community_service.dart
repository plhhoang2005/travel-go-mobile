import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/community_trip.dart';
import '../models/trip_review.dart';

class CommunityService {
  static const String tripsTableName = 'trips';
  static const String reviewsTableName = 'trip_reviews';

  final SupabaseClient? _injectedClient;

  CommunityService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient _getRequiredClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Chưa thể kết nối tới cơ sở dữ liệu Supabase.');
    }
    return client;
  }

  String _getAuthenticatedUserId(SupabaseClient client) {
    final session = client.auth.currentSession;
    final currentUser = client.auth.currentUser;
    if (session == null ||
        currentUser == null ||
        currentUser.id.trim().isEmpty ||
        session.isExpired) {
      throw StateError(
        'Người dùng chưa đăng nhập hoặc phiên làm việc đã hết hạn. Vui lòng đăng nhập.',
      );
    }
    return currentUser.id;
  }

  /// Tạo payload cho bản sao chuyến đi (Clone Trip) độc lập 100%
  static Map<String, dynamic> buildClonedTripPayload({
    required CommunityTrip original,
    required String newUserId,
    String? newTitle,
  }) {
    if (newUserId.trim().isEmpty) {
      throw ArgumentError('Mã người dùng mới (newUserId) không được để trống.');
    }

    // Deep clone ai_plan_data để bảo toàn 100% hoạt động và không bị tham chiếu chéo
    Map<String, dynamic> clonedPlanData = {};
    if (original.tripData.isNotEmpty) {
      try {
        clonedPlanData = Map<String, dynamic>.from(
          jsonDecode(jsonEncode(original.tripData)) as Map,
        );
      } catch (_) {
        clonedPlanData = Map<String, dynamic>.from(original.tripData);
      }
    }

    return {
      'id': const Uuid().v4(),
      'user_id': newUserId,
      'title': newTitle ?? 'Bản sao - ${original.title}',
      'destination_name': original.destination,
      'num_days': original.daysCount,
      'budget_total': original.estimatedCostVnd,
      'start_date': original.startDate?.toIso8601String(),
      'end_date': original.endDate?.toIso8601String(),
      'status': 'planning',
      'is_public': false,
      'author_name': null,
      'like_count': 0,
      'average_rating': 0.0,
      'review_count': 0,
      'ai_plan_data': clonedPlanData,
    };
  }

  /// Lấy danh sách các chuyến đi được chia sẻ công khai (Community Feed)
  Future<List<CommunityTrip>> fetchPublicTrips({
    int limit = 20,
    int offset = 0,
    String? destinationQuery,
  }) async {
    final client = _getRequiredClient();

    var query = client
        .from(tripsTableName)
        .select()
        .eq('is_public', true);

    if (destinationQuery != null && destinationQuery.trim().isNotEmpty) {
      query = query.ilike('destination_name', '%${destinationQuery.trim()}%');
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final list = (response as List<dynamic>)
        .map((item) => CommunityTrip.fromJson(item as Map<String, dynamic>))
        .toList();
    return list;
  }

  /// Sao chép chuyến đi công khai vào danh sách chuyến đi của người dùng hiện tại
  Future<CommunityTrip> cloneTrip({
    required CommunityTrip sourceTrip,
    String? newTitle,
  }) async {
    final client = _getRequiredClient();
    final authenticatedUserId = _getAuthenticatedUserId(client);

    if (sourceTrip.id.trim().isEmpty) {
      throw ArgumentError('Chuyến đi nguồn không có mã định danh hợp lệ.');
    }

    // Kiểm tra tính hợp lệ: chuyến đi phải là công khai hoặc thuộc chính người dùng
    if (!sourceTrip.isPublic && sourceTrip.authorId != authenticatedUserId) {
      throw StateError(
        'Không thể sao chép chuyến đi riêng tư của người dùng khác.',
      );
    }

    final payload = buildClonedTripPayload(
      original: sourceTrip,
      newUserId: authenticatedUserId,
      newTitle: newTitle,
    );

    final response = await client
        .from(tripsTableName)
        .insert(payload)
        .select()
        .single();

    final cloned = CommunityTrip.fromJson(response);
    if (cloned.id.isEmpty || cloned.authorId != authenticatedUserId) {
      throw StateError('Máy chủ không thể tạo bản sao chuyến đi hợp lệ.');
    }
    return cloned;
  }

  /// Gửi hoặc cập nhật đánh giá (1-5 sao + nhận xét) cho chuyến đi công khai
  Future<TripReview> submitTripReview({
    required String tripId,
    required int rating,
    String? comment,
    String? userName,
  }) async {
    final client = _getRequiredClient();
    final authenticatedUserId = _getAuthenticatedUserId(client);

    if (tripId.trim().isEmpty) {
      throw ArgumentError('Mã chuyến đi không được để trống.');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Điểm đánh giá phải từ 1 đến 5 sao.');
    }
    if (comment != null && comment.length > 5000) {
      throw ArgumentError('Nhận xét không được vượt quá 5.000 ký tự.');
    }

    final currentUser = client.auth.currentUser;
    final resolvedName = (userName != null && userName.trim().isNotEmpty)
        ? userName.trim()
        : ((currentUser?.userMetadata?['full_name'] as String?)?.trim().isNotEmpty == true
            ? (currentUser!.userMetadata!['full_name'] as String).trim()
            : 'Thành viên TravelGO');

    final payload = {
      'trip_id': tripId,
      'user_id': authenticatedUserId,
      'user_name': resolvedName,
      'rating': rating,
      'comment': comment?.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final response = await client
        .from(reviewsTableName)
        .upsert(payload, onConflict: 'trip_id, user_id')
        .select()
        .single();

    return TripReview.fromJson(response);
  }

  /// Lấy danh sách đánh giá của một chuyến đi
  Future<List<TripReview>> fetchTripReviews(String tripId) async {
    final client = _getRequiredClient();

    if (tripId.trim().isEmpty) {
      throw ArgumentError('Mã chuyến đi không được để trống.');
    }

    final response = await client
        .from(reviewsTableName)
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);

    final list = (response as List<dynamic>)
        .map((item) => TripReview.fromJson(item as Map<String, dynamic>))
        .toList();
    return list;
  }

  /// Bật hoặc tắt trạng thái chia sẻ công khai của chuyến đi (chỉ chủ sở hữu được phép)
  Future<CommunityTrip> toggleTripPublic({
    required String tripId,
    required bool isPublic,
    String? authorName,
  }) async {
    final client = _getRequiredClient();
    final authenticatedUserId = _getAuthenticatedUserId(client);

    if (tripId.trim().isEmpty) {
      throw ArgumentError('Mã chuyến đi không được để trống.');
    }

    final updatePayload = <String, dynamic>{
      'is_public': isPublic,
      if (authorName != null && authorName.trim().isNotEmpty)
        'author_name': authorName.trim(),
    };

    final response = await client
        .from(tripsTableName)
        .update(updatePayload)
        .eq('id', tripId)
        .eq('user_id', authenticatedUserId)
        .select()
        .single();

    return CommunityTrip.fromJson(response);
  }
}
