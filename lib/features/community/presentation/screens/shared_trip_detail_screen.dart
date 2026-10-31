import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/community_trip.dart';
import '../../models/trip_review.dart';
import '../../services/community_service.dart';
import '../../../../core/presentation/travel_image.dart';
import '../widgets/community_trip_card.dart';
import '../widgets/rating_stars_widget.dart';

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
  bool _isLoadingReviews = true;
  String? _reviewsError;

  // Trạng thái cho form đánh giá
  int _userRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingReview = false;

  // Trạng thái cho nút vàng Clone Trip
  bool _isCloning = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CommunityService();
    _trip = widget.trip;
    _loadReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoadingReviews = true;
      _reviewsError = null;
    });

    try {
      final reviews = await _service.fetchTripReviews(_trip.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
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

  Future<void> _submitReview() async {
    final comment = _commentController.text.trim();
    if (_isSubmittingReview) return;

    setState(() => _isSubmittingReview = true);

    try {
      final review = await _service.submitTripReview(
        tripId: _trip.id,
        rating: _userRating,
        comment: comment.isNotEmpty ? comment : null,
      );

      if (mounted) {
        _commentController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi đánh giá thành công! Cảm ơn bạn.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message
                  : 'Gửi đánh giá không thành công. Vui lòng kiểm tra đăng nhập.',
            ),
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
    if (planData.isEmpty) return const [];

    dynamic rawDays;
    if (planData.containsKey('plan') && planData['plan'] is Map) {
      final planMap = planData['plan'] as Map<String, dynamic>;
      rawDays = planMap['itineraryDays'];
    } else if (planData.containsKey('itineraryDays')) {
      rawDays = planData['itineraryDays'];
    }

    if (rawDays is List) {
      return rawDays
          .whereType<Map>()
          .map((d) => Map<String, dynamic>.from(d))
          .toList();
    }
    return const [];
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
                        Container(
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        Row(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Thời lượng: $daysCount ngày',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.slate700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          budget != null
                              ? 'Dự toán: ${currencyFmt.format(budget)}'
                              : 'Chưa có dự toán',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
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
                                        act['costVnd'] > 0)
                                      Text(
                                        currencyFmt.format(act['costVnd']),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.slate500,
                                        ),
                                      ),
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
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chia sẻ cảm nhận về chuyến đi này:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate800,
                      ),
                    ),
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
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Nhận xét của bạn về lịch trình này…',
                        hintStyle: const TextStyle(fontSize: 13),
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
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
                            : const Text('Gửi nhận xét'),
                      ),
                    ),
                  ],
                ),
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
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.slate100),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            RatingStarsWidget(
                              rating: review.rating.toDouble(),
                              size: 16,
                            ),
                            if (review.createdAt != null)
                              Text(
                                DateFormat('dd/MM/yyyy')
                                    .format(review.createdAt!.toLocal()),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.slate400,
                                ),
                              ),
                          ],
                        ),
                        if (review.comment != null &&
                            review.comment!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            review.comment!.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.slate800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
              label: Text(
                _isCloning
                    ? 'Đang sao chép…'
                    : 'Sao chép về chuyến đi của tôi',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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
