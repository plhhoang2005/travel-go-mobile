import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../trips/providers/saved_trips_provider.dart';
import '../../models/community_trip.dart';
import '../../models/trip_review.dart';
import '../../models/trip_review_reply.dart';
import '../../services/community_service.dart';
import '../../../../core/presentation/travel_image.dart';
import '../widgets/community_trip_card.dart';
import '../../../reviews/presentation/widgets/rating_stars_widget.dart';

/// Màn hình Chi tiết Chuyến đi được chia sẻ trên Cộng đồng.
/// Bao gồm:
/// 1. Thông tin tổng quan (Điểm đến, Tác giả, Thời lượng, Dự toán ngân sách).
/// 2. Danh sách hoạt động theo ngày trích xuất từ ai_plan_data.
/// 3. Khu vực Đánh giá: Điểm sao trung bình, danh sách nhận xét & Form chấm sao gửi review.
/// 4. Nút Vàng CTA: "Sao chép về chuyến đi của tôi" (Clone Trip) - Tính năng cốt lõi Thành viên 4.
class SharedTripDetailScreen extends StatefulWidget {
  final CommunityTrip trip;
  final CommunityService? service;

  const SharedTripDetailScreen({
    super.key,
    required this.trip,
    this.service,
  });

  @override
  State<SharedTripDetailScreen> createState() => _SharedTripDetailScreenState();
}

class _SharedTripDetailScreenState extends State<SharedTripDetailScreen> {
  late final CommunityService _service;
  late CommunityTrip _trip;

  List<TripReview> _reviews = [];
  List<TripReviewReply> _replies = [];
  bool _isLoadingReviews = true;
  String? _reviewsError;

  // Trạng thái cho form đánh giá & chỉnh sửa
  int _userRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;
  bool _isEditingReview = false;

  // Trạng thái cho nút vàng Clone Trip
  bool _isCloning = false;

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CommunityService();
    _trip = widget.trip;
    _commentController.addListener(_onCommentChanged);
    _loadReviews();
  }

  void _onCommentChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
      _reviewsError = null;
    });

    try {
      final reviewsFuture = _service.fetchTripReviews(_trip.id);
      final repliesFuture = _service.fetchTripReviewReplies(_trip.id);
      final results = await Future.wait([reviewsFuture, repliesFuture]);

      if (mounted) {
        setState(() {
          _reviews = results[0] as List<TripReview>;
          _replies = results[1] as List<TripReviewReply>;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reviewsError = 'Không thể tải danh sách nhận xét: $e';
          _isLoadingReviews = false;
        });
      }
    }
  }

  void _startEditReview(TripReview review) {
    setState(() {
      _isEditingReview = true;
      _userRating = review.rating;
      _commentController.text = review.comment ?? '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang sửa đánh giá. Vui lòng chỉnh sửa và bấm Cập nhật.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cancelEditReview() {
    setState(() {
      _isEditingReview = false;
      _userRating = 5;
      _commentController.clear();
    });
  }

  Future<void> _confirmDeleteReview(TripReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa đánh giá?'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa đánh giá của mình không? Điểm đánh giá trung bình sẽ được tính lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteTripReview(tripId: _trip.id, reviewId: review.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa đánh giá thành công.'),
            backgroundColor: AppTheme.accentEmerald,
          ),
        );
        final updated = _reviews.where((r) => r.id != review.id).toList();
        final newCount = updated.length;
        final newAvg = newCount > 0
            ? updated.fold<double>(0, (sum, r) => sum + r.rating) / newCount
            : 0.0;
        setState(() {
          _reviews = updated;
          _trip = _trip.copyWith(
            reviewCount: newCount,
            averageRating: double.parse(newAvg.toStringAsFixed(1)),
          );
          if (_isEditingReview) {
            _isEditingReview = false;
            _userRating = 5;
            _commentController.clear();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể xóa đánh giá: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _openReplySheet(TripReview review) {
    final replyController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Phản hồi cho ${review.userName}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.slate800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '"${review.comment ?? 'Đánh giá ${review.rating} sao'}"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.slate500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('reply-comment-input'),
                  controller: replyController,
                  maxLines: 3,
                  minLines: 2,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Nhập câu trả lời của bạn…',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('reply-submit-btn'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isSending
                        ? null
                        : () async {
                            final text = replyController.text.trim();
                            if (text.isEmpty) return;
                            setSheetState(() => isSending = true);
                            try {
                              final newReply = await _service.submitReviewReply(
                                tripId: _trip.id,
                                reviewId: review.id,
                                comment: text,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (mounted) {
                                setState(() {
                                  _replies = [..._replies, newReply];
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã gửi phản hồi thành công!'),
                                    backgroundColor: AppTheme.accentEmerald,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => isSending = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Không thể gửi phản hồi: $e'),
                                    backgroundColor: const Color(0xFFEF4444),
                                  ),
                                );
                              }
                            }
                          },
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Gửi phản hồi'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteReply(TripReviewReply reply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa phản hồi?'),
        content: const Text('Bạn có chắc chắn muốn xóa phản hồi này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteReviewReply(replyId: reply.id);
      if (mounted) {
        setState(() {
          _replies = _replies.where((r) => r.id != reply.id).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa phản hồi.'),
            backgroundColor: AppTheme.accentEmerald,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể xóa phản hồi: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _submitReview() async {
    final comment = _commentController.text.trim();
    if (_isSubmittingReview) return;

    if (comment.isNotEmpty) {
      final words = _countWords(comment);
      if (words > 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nội dung nhận xét tối đa 1.000 từ (hiện có $words từ). Vui lòng rút gọn.',
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    setState(() => _isSubmittingReview = true);

    try {
      final review = await _service.submitTripReview(
        tripId: _trip.id,
        rating: _userRating,
        comment: comment.isNotEmpty ? comment : null,
      );

      if (mounted) {
        final wasEditing = _isEditingReview;
        _commentController.clear();
        setState(() {
          _isEditingReview = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasEditing
                  ? 'Đã cập nhật đánh giá thành công!'
                  : 'Đã gửi đánh giá thành công! Cảm ơn bạn.',
            ),
            backgroundColor: AppTheme.accentEmerald,
          ),
        );

        // Cập nhật lại danh sách review và số liệu hiển thị
        await _loadReviews();

        // Tự động tính lại trung bình trên client nếu trigger chưa kịp cập nhật view
        final updatedReviews = List<TripReview>.from(_reviews);
        final existingIdx =
            updatedReviews.indexWhere((r) => r.userId == review.userId);
        if (existingIdx >= 0) {
          updatedReviews[existingIdx] = review;
        } else {
          updatedReviews.insert(0, review);
        }

        final newCount = updatedReviews.length;
        final newAvg = newCount > 0
            ? updatedReviews.fold<double>(0, (sum, r) => sum + r.rating) /
                newCount
            : 0.0;

        setState(() {
          _reviews = updatedReviews;
          _trip = _trip.copyWith(
            reviewCount: newCount,
            averageRating: double.parse(newAvg.toStringAsFixed(1)),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage;
        if (e is StateError) {
          errorMessage = e.message;
        } else if (e is ArgumentError) {
          errorMessage = e.message;
        } else if (e is PostgrestException) {
          errorMessage = 'Lỗi máy chủ (${e.code ?? "CSDL"}): ${e.message}';
        } else {
          final errStr = e.toString();
          if (errStr.contains('JWT') ||
              errStr.contains('auth') ||
              errStr.contains('session') ||
              errStr.contains('đăng nhập')) {
            errorMessage =
                'Gửi đánh giá không thành công. Vui lòng kiểm tra đăng nhập.';
          } else {
            errorMessage = 'Gửi đánh giá không thành công: $errStr';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _handleCloneTrip() async {
    if (_isCloning) return;

    setState(() => _isCloning = true);

    try {
      final clonedTrip = await _service.cloneTrip(sourceTrip: _trip);
      if (mounted) {
        try {
          final auth = context.read<AuthProvider>();
          final currentUserId = auth.currentUser?.id;
          if (currentUserId != null && currentUserId.isNotEmpty) {
            await context.read<SavedTripsProvider>().loadTrips(currentUserId);
          }
        } catch (_) {
          // Bỏ qua lỗi nếu Provider không nằm trong cây widget
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã sao chép "${clonedTrip.title}" về Chuyến đi của bạn!',
              ),
              backgroundColor: AppTheme.accentEmerald,
              action: SnackBarAction(
                label: 'Đóng',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message
                  : 'Không thể sao chép chuyến đi. Vui lòng đăng nhập tài khoản.',
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCloning = false);
    }
  }

  List<Map<String, dynamic>> _extractItineraryDays() {
    final planData = _trip.tripData;
    dynamic rawDays;

    if (planData.isNotEmpty) {
      if (planData.containsKey('plan') && planData['plan'] is Map) {
        final planMap = planData['plan'] as Map<String, dynamic>;
        rawDays = planMap['itineraryDays'] ??
            planMap['itinerary_days'] ??
            planMap['days'] ??
            planMap['itinerary'];
      } else if (planData.containsKey('itineraryDays')) {
        rawDays = planData['itineraryDays'];
      } else if (planData.containsKey('itinerary_days')) {
        rawDays = planData['itinerary_days'];
      } else if (planData.containsKey('days')) {
        rawDays = planData['days'];
      } else if (planData.containsKey('itinerary')) {
        rawDays = planData['itinerary'];
      }
    }

    if (rawDays is List && rawDays.isNotEmpty) {
      return rawDays
          .whereType<Map>()
          .map((d) => Map<String, dynamic>.from(d))
          .toList();
    }

    return _generateFallbackDays();
  }

  List<Map<String, dynamic>> _generateFallbackDays() {
    final count = (_trip.daysCount != null && _trip.daysCount! > 0)
        ? _trip.daysCount!
        : 1;
    final dest = _trip.destination.trim().isNotEmpty
        ? _trip.destination.trim()
        : 'điểm đến';
    final List<Map<String, dynamic>> days = [];
    for (var i = 1; i <= count; i++) {
      days.add({
        'day': i,
        'title': 'Ngày $i: Khám phá $dest',
        'activities': [
          {
            'time': '08:00',
            'title': 'Tham quan và trải nghiệm $dest',
            'costVnd': 0,
            'durationHours': 2.0,
          },
        ],
      });
    }
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );

    final destination = _trip.destination.trim().isNotEmpty
        ? _trip.destination.trim()
        : 'Việt Nam';

    final daysCount = _trip.daysCount ?? 1;
    final budget = _trip.estimatedCostVnd?.toInt();
    final author = _trip.authorName?.trim().isNotEmpty == true
        ? _trip.authorName!.trim()
        : 'Thành viên TravelGO';

    final itineraryDays = _extractItineraryDays();
    final currentUserId = context.watch<AuthProvider?>()?.currentUser?.id ?? _service.currentUserId;
    final myReview = (currentUserId != null && currentUserId.isNotEmpty)
        ? _reviews.where((r) => r.userId == currentUserId).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: Text(
          _trip.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Ảnh đại diện điểm đến nếu có
            if (CommunityTripCard.resolveDestinationMedia(destination) case final media?) ...[
              TravelImage(
                media: media,
                semanticLabel: media.caption,
                height: 180,
              ),
              const SizedBox(height: 16),
            ],
            // Card Tổng quan chuyến đi
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border, width: 1),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              destination,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 20,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _trip.averageRating > 0
                                  ? _trip.averageRating.toStringAsFixed(1)
                                  : 'Mới',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ratingText,
                              ),
                            ),
                            if (_trip.reviewCount > 0)
                              Text(
                                ' (${_trip.reviewCount} đánh giá)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.slate500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _trip.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tác giả: $author',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.slate600,
                      ),
                    ),
                    const Divider(height: 24, color: AppTheme.slate100),
                    Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: AppTheme.slate500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Thời lượng: $daysCount ngày',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.slate700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                budget != null
                                    ? 'Dự toán: ${currencyFmt.format(budget)}'
                                    : 'Chưa có dự toán',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Mục Lịch trình chi tiết
            Text(
              'Lịch trình các ngày',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate900,
                  ),
            ),
            const SizedBox(height: 8),

            if (itineraryDays.isEmpty)
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.border),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Chuyến đi này chưa có lịch trình chi tiết theo ngày.',
                      style: TextStyle(color: AppTheme.slate500),
                    ),
                  ),
                ),
              )
            else
              for (final day in itineraryDays) ...[
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primarySoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Ngày ${day['day'] ?? ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                day['title'] as String? ?? 'Khám phá',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.slate800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (day['activities'] is List &&
                            (day['activities'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final act in (day['activities'] as List))
                            if (act is Map)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ',
                                        style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold)),
                                    if (act['time'] != null &&
                                        act['time'].toString().isNotEmpty)
                                      Text(
                                        '${act['time']}: ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: AppTheme.slate600,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        act['title'] as String? ?? '',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.slate800,
                                        ),
                                      ),
                                    ),
                                    if (act['costVnd'] != null &&
                                        act['costVnd'] > 0) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        currencyFmt.format(act['costVnd']),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.slate500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

            const SizedBox(height: 24),

            // Khu vực Đánh giá & Nhận xét
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Đánh giá & Nhận xét',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate900,
                      ),
                ),
                Text(
                  '${_reviews.length} nhận xét',
                  style: const TextStyle(fontSize: 12, color: AppTheme.slate500),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Form Chấm sao & Viết nhận xét
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.border),
              ),
              child: Builder(
                builder: (context) {
                  final wordCount = _countWords(_commentController.text);
                  final isOverLimit = wordCount > 1000;
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isEditingReview
                                  ? 'Chỉnh sửa đánh giá của bạn:'
                                  : 'Chia sẻ cảm nhận về chuyến đi này:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isEditingReview
                                    ? AppTheme.primaryColor
                                    : AppTheme.slate800,
                              ),
                            ),
                            if (_isEditingReview)
                              TextButton(
                                onPressed: _cancelEditReview,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Hủy sửa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.slate500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (!_isEditingReview && myReview != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Bạn đã đánh giá chuyến đi này (${myReview.rating} sao). Bạn có thể chỉnh sửa lại bất cứ lúc nào.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.slate500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Center(
                          child: RatingStarsWidget(
                            rating: _userRating.toDouble(),
                            interactive: true,
                            size: 28,
                            onRatingChanged: (newRating) {
                              setState(() => _userRating = newRating);
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _commentController,
                          maxLines: 4,
                          minLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Nhận xét của bạn về lịch trình này…',
                            hintStyle: const TextStyle(fontSize: 13),
                            contentPadding: const EdgeInsets.all(12),
                            helperText: 'Tối đa 1.000 từ ($wordCount/1.000 từ)',
                            helperStyle: TextStyle(
                              fontSize: 11,
                              color: isOverLimit
                                  ? const Color(0xFFEF4444)
                                  : AppTheme.slate500,
                              fontWeight:
                                  isOverLimit ? FontWeight.bold : FontWeight.normal,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isOverLimit
                                    ? const Color(0xFFEF4444)
                                    : AppTheme.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isOverLimit
                                    ? const Color(0xFFEF4444)
                                    : AppTheme.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isOverLimit
                                    ? const Color(0xFFEF4444)
                                    : AppTheme.primaryColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmittingReview ? null : _submitReview,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmittingReview
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditingReview
                                    ? 'Cập nhật đánh giá'
                                    : (myReview != null
                                        ? 'Cập nhật nhận xét'
                                        : 'Gửi nhận xét'),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
            const SizedBox(height: 16),

            // Danh sách các nhận xét từ người dùng
            if (_isLoadingReviews)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_reviewsError != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  _reviewsError!,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                ),
              )
            else if (_reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Chưa có nhận xét nào. Hãy là người đầu tiên đánh giá chuyến đi này!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.slate500, fontSize: 13),
                  ),
                ),
              )
            else
              for (final review in _reviews) ...[
                () {
                  final isMyReview = currentUserId != null &&
                      review.userId.isNotEmpty &&
                      review.userId == currentUserId;
                  final reviewReplies = _replies
                      .where((r) => r.reviewId == review.id)
                      .toList();

                  final initialLetter = review.userName.trim().isNotEmpty
                      ? review.userName.trim()[0].toUpperCase()
                      : 'U';

                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isMyReview
                            ? AppTheme.primaryColor.withValues(alpha: 0.3)
                            : AppTheme.slate200,
                        width: isMyReview ? 1.2 : 1.0,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Header: Avatar + Tên + Badge Bạn + Điểm sao + Ngày giờ + Nút sửa/xóa
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isMyReview
                                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                    : AppTheme.slate100,
                                child: Text(
                                  initialLetter,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isMyReview
                                        ? AppTheme.primaryColor
                                        : AppTheme.slate700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      runSpacing: 2,
                                      children: [
                                        Text(
                                          review.userName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.slate800,
                                          ),
                                        ),
                                        if (isMyReview)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Bạn',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        RatingStarsWidget(
                                          rating: review.rating.toDouble(),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        if (review.createdAt != null)
                                          Text(
                                            DateFormat('dd/MM/yyyy HH:mm')
                                                .format(review.createdAt!.toLocal()),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.slate400,
                                            ),
                                          ),
                                        if (review.updatedAt != null &&
                                            review.createdAt != null &&
                                            review.updatedAt!
                                                    .difference(review.createdAt!)
                                                    .inSeconds
                                                    .abs() >
                                                60) ...[
                                          const SizedBox(width: 4),
                                          const Text(
                                            '(Đã sửa)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.slate400,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Nút Sửa / Xóa cho chủ đánh giá
                              if (isMyReview)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      key: const ValueKey('edit-my-review-btn'),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      color: AppTheme.slate600,
                                      tooltip: 'Chỉnh sửa đánh giá',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _startEditReview(review),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      key: const ValueKey('delete-my-review-btn'),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                      color: const Color(0xFFEF4444),
                                      tooltip: 'Xóa đánh giá',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDeleteReview(review),
                                    ),
                                  ],
                                ),
                            ],
                          ),

                          // 2. Nội dung nhận xét
                          if (review.comment != null &&
                              review.comment!.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            _ExpandableReviewComment(
                              comment: review.comment!.trim(),
                            ),
                          ],

                          // 3. Danh sách phản hồi (Replies)
                          if (reviewReplies.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            for (final reply in reviewReplies) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.slate50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.slate200),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 11,
                                          backgroundColor: AppTheme.primaryColor
                                              .withValues(alpha: 0.1),
                                          child: Text(
                                            reply.userName.trim().isNotEmpty
                                                ? reply.userName.trim()[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Wrap(
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            spacing: 4,
                                            runSpacing: 2,
                                            children: [
                                              Text(
                                                reply.userName,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.slate800,
                                                ),
                                              ),
                                              if (reply.userId == _trip.authorId)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor,
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Tác giả',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              if (reply.userId == currentUserId)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 1,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Bạn',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd/MM HH:mm')
                                              .format(reply.createdAt.toLocal()),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.slate400,
                                          ),
                                        ),
                                        if (reply.userId == currentUserId)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: IconButton(
                                              key: ValueKey('delete-reply-${reply.id}'),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                              ),
                                              color: AppTheme.slate400,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              tooltip: 'Xóa phản hồi',
                                              onPressed: () =>
                                                  _confirmDeleteReply(reply),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 28),
                                      child: Text(
                                        reply.comment,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.slate700,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],

                          // 4. Nút bấm "Trả lời"
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              key: ValueKey('reply-btn-${review.id}'),
                              onPressed: () => _openReplySheet(review),
                              icon: const Icon(Icons.reply_rounded, size: 16),
                              label: const Text(
                                'Trả lời',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: AppTheme.primaryColor,
                              ),
                            ),

                          ),
                        ],
                      ),
                    ),
                  );
                }(),
              ],

            // Khoảng trống dưới cùng để không bị nút đáy che khuất
            const SizedBox(height: 80),
          ],
        ),
      ),
      // Nút Vàng CTA: "Sao chép về chuyến đi của tôi" (Golden Feature)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              key: const ValueKey('clone-trip-cta-button'),
              onPressed: _isCloning ? null : _handleCloneTrip,
              icon: _isCloning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black87,
                      ),
                    )
                  : const Icon(
                      Icons.copy_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _isCloning
                      ? 'Đang sao chép…'
                      : 'Sao chép về chuyến đi của tôi',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                // Nút màu vàng theo đúng yêu cầu đề tài đồ án
                backgroundColor: const Color(0xFFF59E0B), // Amber 500
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget hiển thị nội dung nhận xét có cơ chế mở rộng / thu gọn
/// khi nhận xét vượt quá 3 dòng hoặc quá dài, tránh vỡ bố cục màn hình.
class _ExpandableReviewComment extends StatefulWidget {
  final String comment;
  const _ExpandableReviewComment({required this.comment});

  @override
  State<_ExpandableReviewComment> createState() => _ExpandableReviewCommentState();
}

class _ExpandableReviewCommentState extends State<_ExpandableReviewComment> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      fontSize: 13,
      color: AppTheme.slate800,
      height: 1.45,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final span = TextSpan(text: widget.comment, style: textStyle);
        final maxWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 320.0;
        final tp = TextPainter(
          text: span,
          textDirection: Directionality.of(context),
          maxLines: 3,
        )..layout(maxWidth: maxWidth);

        final isLong = tp.didExceedMaxLines ||
            widget.comment.split('\n').length > 3 ||
            widget.comment.length > 100;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.comment,
              style: textStyle,
              maxLines: _isExpanded ? null : 3,
              overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (isLong)
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? 'Thu gọn' : 'Xem thêm',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.tealPrimary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppTheme.tealPrimary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

