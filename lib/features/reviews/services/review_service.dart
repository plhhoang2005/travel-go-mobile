import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place_review.dart';

class ReviewException implements Exception {
  final String code;
  final String message;
  const ReviewException(this.code, this.message);

  @override
  String toString() => message;
}

class ReviewService {
  final SupabaseClient? client;
  final bool Function(String placeId)? placeValidator;

  ReviewService({this.client, this.placeValidator});

  bool get canSubmit => client?.auth.currentUser != null;

  Future<List<PlaceReview>> fetchReviews(String placeId) async {
    _validatePlaceId(placeId);
    final supabase = client;
    if (supabase == null) {
      throw const ReviewException(
        'unavailable',
        'Chưa kết nối được dịch vụ đánh giá.',
      );
    }
    try {
      final rows = await supabase
          .from('place_reviews')
          .select()
          .eq('place_id', placeId)
          .order('created_at', ascending: false);
      return rows
          .map((row) => PlaceReview.fromJson(Map<String, dynamic>.from(row)))
          .toList(growable: false);
    } on ReviewException {
      rethrow;
    } catch (error) {
      throw ReviewException('fetch_failed', 'Không thể tải đánh giá: $error');
    }
  }

  Future<PlaceReview> submitReview({
    required String placeId,
    required int rating,
    required String comment,
    String? expectedUserId,
  }) async {
    _validatePlaceId(placeId);
    if (rating < 1 || rating > 5) {
      throw const ReviewException(
        'invalid_rating',
        'Vui lòng chọn từ 1 đến 5 sao.',
      );
    }
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) {
      throw const ReviewException('invalid_comment', 'Vui lòng nhập nhận xét.');
    }
    final supabase = client;
    final user = supabase?.auth.currentUser;
    if (supabase == null || user == null) {
      throw const ReviewException(
        'auth_required',
        'Bạn cần đăng nhập để gửi đánh giá.',
      );
    }
    if (expectedUserId != null && user.id != expectedUserId) {
      throw const ReviewException(
        'auth_changed',
        'Phiên đăng nhập đã thay đổi. Hãy thử lại.',
      );
    }
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final metadataName = metadata['full_name'] ?? metadata['name'];
    final displayName = metadataName is String && metadataName.trim().isNotEmpty
        ? metadataName.trim()
        : (user.email ?? 'Người dùng TravelGO');
    try {
      final row = await supabase
          .from('place_reviews')
          .insert({
            'place_id': placeId,
            'user_id': user.id,
            'user_name': displayName,
            'rating': rating,
            'comment': trimmedComment,
          })
          .select()
          .single();
      return PlaceReview.fromJson(Map<String, dynamic>.from(row));
    } on ReviewException {
      rethrow;
    } catch (error) {
      throw ReviewException('submit_failed', 'Không thể gửi đánh giá: $error');
    }
  }

  void _validatePlaceId(String placeId) {
    if (placeId.trim().isEmpty ||
        (placeValidator != null && !placeValidator!(placeId))) {
      throw const ReviewException(
        'invalid_place',
        'Địa điểm không tồn tại trong catalogue hiện tại.',
      );
    }
  }
}
